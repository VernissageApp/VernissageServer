//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import NIOCore
import Synchronization
import Testing
import Vapor
import VaporTesting

struct RemoteResourceDownloadServiceTests {
    @Test
    func `Uses a dedicated DNS pool that shuts down with the application`() async throws {
        let pool = try await withApp(configure: { app in
            app.configureRemoteResourceDNS()
        }) { app in
            let pool = try #require(app.remoteResourceDNSPool)
            #expect(pool.numberOfThreads == 2)
            #expect(pool !== app.threadPool)

            app.configureRemoteResourceDNS()
            #expect(app.remoteResourceDNSPool === pool)

            let request = Request(application: app, on: app.eventLoopGroup.next())
            let service = RemoteResourceDownloadService(transport: { _, _, _, _ in
                Issue.record("A local address must not reach the transport")
                return ClientResponse(status: .ok)
            })

            await #expect(throws: RemoteResourceDownloadError.nonPublicAddress) {
                try await service.download(url: "http://localhost/image.png", on: request.executionContext)
            }
            return pool
        }

        await #expect(throws: CancellationError.self) {
            try await pool.runIfActive { 1 }
        }
    }

    @Test(arguments: ["127.0.0.1", "10.0.0.1", "100.64.0.1", "169.254.0.1", "172.16.0.1", "192.168.0.1",
                      "192.0.2.1", "198.18.0.1", "224.0.0.1", "::", "::1", "::ffff:127.0.0.1", "fc00::1",
                      "fe80::1", "ff02::1", "2001:db8::1", "2002::1", "3fff::1"])
    func `Rejects non-public address ranges`(address: String) async {
        await #expect(throws: RemoteResourceDownloadError.nonPublicAddress) {
            try await download(url: "https://images.example/photo.png", resolve: { _ in
                [address]
            }, fetch: { _, _, _, _ in
                Issue.record("A non-public address must not reach the transport")
                return ClientResponse(status: .ok)
            })
        }
    }

    @Test(arguments: ["1.1.1.1", "8.8.8.8", "2606:4700:4700::1111"])
    func `Accepts public address ranges`(address: String) async throws {
        let expectedBody = ByteBuffer(string: "image bytes")
        let body = try await download(url: "https://images.example/photo.png", resolve: { _ in
            [address]
        }, fetch: { _, _, verifiedAddress, connectTimeout in
            #expect(verifiedAddress == address)
            #expect(connectTimeout == nil)
            return ClientResponse(status: .ok, body: expectedBody)
        })

        #expect(body == expectedBody)
    }

    @Test(arguments: ["file:///example.png", "http://user:password@images.example/image.png", "http://images.example:65536/"])
    func `Rejects unsupported URLs before resolution`(url: String) async {
        await #expect(throws: RemoteResourceDownloadError.invalidURL) {
            try await download(url: url, resolve: { _ in
                Issue.record("An invalid URL must not be resolved")
                return []
            }, fetch: { _, _, _, _ in
                Issue.record("An invalid URL must not be requested")
                return ClientResponse(status: .ok)
            })
        }
    }

    @Test
    func `Rejects a host with mixed public and private DNS results before connecting`() async {
        await #expect(throws: RemoteResourceDownloadError.nonPublicAddress) {
            try await download(url: "https://images.example/photo.png", resolve: { _ in
                ["1.1.1.1", "10.0.0.1"]
            }, fetch: { _, _, _, _ in
                Issue.record("An ineligible destination must not be requested")
                return ClientResponse(status: .ok)
            })
        }
    }

    @Test
    func `Revalidates each public redirect and passes the checked address to the transport`() async throws {
        let requestedURLs = Mutex<[String]>([])
        let resolvedHosts = Mutex<[String]>([])

        let body = try await download(url: "https://images.example/photo.png", resolve: { host in
            resolvedHosts.withLock { $0.append(host) }
            return host == "images.example" ? ["1.1.1.1"] : ["2606:4700:4700::1111"]
        }, fetch: { url, host, address, _ in
            requestedURLs.withLock { $0.append(url.absoluteString) }
            #expect(url.host == host)
            if host == "images.example" {
                #expect(address == "1.1.1.1")
                return ClientResponse(status: .found, headers: ["Location": "https://cdn.example/asset.png"])
            }
            #expect(address == "2606:4700:4700::1111")
            return ClientResponse(status: .ok, body: ByteBuffer(string: "image bytes"))
        })

        #expect(resolvedHosts.withLock { $0 } == ["images.example", "cdn.example"])
        #expect(requestedURLs.withLock { $0 } == ["https://images.example/photo.png", "https://cdn.example/asset.png"])
        #expect(body == ByteBuffer(string: "image bytes"))
    }

    @Test
    func `Stops a redirect before requesting an ineligible destination`() async {
        let requests = Mutex<[String]>([])
        await #expect(throws: RemoteResourceDownloadError.nonPublicAddress) {
            try await download(url: "https://images.example/photo.png", resolve: { host in
                host == "images.example" ? ["1.1.1.1"] : ["10.0.0.1"]
            }, fetch: { _, host, _, _ in
                requests.withLock { $0.append(host) }
                return ClientResponse(status: .found, headers: ["Location": "https://internal.example/image.png"])
            })
        }

        #expect(requests.withLock { $0 } == ["images.example"])
    }

    @Test
    func `Stops at the redirect limit`() async {
        let requests = Mutex(0)
        await #expect(throws: RemoteResourceDownloadError.tooManyRedirects) {
            try await download(url: "https://images.example/photo.png", resolve: { _ in
                ["1.1.1.1"]
            }, fetch: { _, _, _, _ in
                requests.withLock { $0 += 1 }
                return ClientResponse(status: .found, headers: ["Location": "/photo.png"])
            })
        }

        #expect(requests.withLock { $0 } == 6)
    }

    @Test
    func `Uses a shorter connect timeout only while another verified address is available`() async throws {
        let addresses = ["2606:4700:4700::1111", "1.1.1.1"]
        let attempts = Mutex<[String]>([])
        let expectedBody = ByteBuffer(string: "image bytes")

        let body = try await download(url: "https://images.example/photo.png", resolve: { _ in
            addresses
        }, fetch: { _, _, address, connectTimeout in
            attempts.withLock { $0.append(address) }

            if address == addresses[0] {
                #expect(connectTimeout == Constants.remoteResourceConnectFallbackTimeout)
                throw URLError(.timedOut)
            }

            #expect(connectTimeout == nil)
            return ClientResponse(status: .ok, body: expectedBody)
        })

        #expect(attempts.withLock { $0 } == addresses)
        #expect(body == expectedBody)
    }

    @Test
    func `Does not retry an oversized download on another verified address`() async {
        let addresses = ["2606:4700:4700::1111", "1.1.1.1"]
        let attempts = Mutex<[String]>([])
        let sizeError = NIOTooManyBytesError(maxBytes: Constants.remoteResourceSizeLimit)

        await #expect(throws: sizeError) {
            try await download(url: "https://images.example/photo.png", resolve: { _ in
                addresses
            }, fetch: { _, _, address, _ in
                attempts.withLock { $0.append(address) }
                throw sizeError
            })
        }

        #expect(attempts.withLock { $0 } == [addresses[0]])
    }

    private func download(
        url: String,
        resolve: @escaping RemoteResourceDownloadService.Resolver,
        fetch: @escaping RemoteResourceDownloadService.Transport
    ) async throws -> ByteBuffer {
        let application = try await Application.make(.testing)
        let request = Request(application: application, on: application.eventLoopGroup.next())
        let service = RemoteResourceDownloadService(resolver: resolve, transport: fetch)

        let result: ByteBuffer
        do {
            result = try await service.download(url: url, on: request.executionContext)
        } catch {
            try? await application.asyncShutdown()
            throw error
        }

        try await application.asyncShutdown()
        return result
    }
}
