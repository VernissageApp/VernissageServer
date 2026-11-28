//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import AsyncHTTPClient
import NIOCore
import NIOPosix
import Vapor

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

extension Application.Services {
    struct RemoteResourceDownloadServiceKey: StorageKey {
        typealias Value = RemoteResourceDownloadServiceType
    }

    var remoteResourceDownloadService: RemoteResourceDownloadServiceType {
        get {
            self.application.storage[RemoteResourceDownloadServiceKey.self] ?? RemoteResourceDownloadService()
        }
        nonmutating set {
            self.application.storage[RemoteResourceDownloadServiceKey.self] = newValue
        }
    }
}

protocol RemoteResourceDownloadServiceType: Sendable {
    /// Downloads a remote file over HTTP or HTTPS using verified public addresses.
    ///
    /// Resolves the destination before each request and rejects it if any of its addresses are non-public.
    /// Connects to a verified IP while retaining the original hostname for HTTP and TLS verification.
    /// Follows up to five redirects and applies the same checks to each destination.
    ///
    /// - Parameters:
    ///   - url: The absolute HTTP or HTTPS URL of the remote file.
    ///   - context: The HTTP request or queue job context that provides the DNS pool and event loop group.
    /// - Returns: The non-empty body of a successful HTTP response.
    /// - Throws: An error if the URL or destination fails validation, a redirect is invalid or exceeds the limit,
    ///   the response fails or has an empty body, the download exceeds the size limit or times out, or the operation is cancelled.
    func download(url: String, on context: ExecutionContext) async throws -> ByteBuffer
}

final class RemoteResourceDownloadService: RemoteResourceDownloadServiceType {
    typealias Resolver = @Sendable (String) async throws -> [String]
    typealias Transport = @Sendable (URL, String, String, TimeAmount?) async throws -> ClientResponse

    // Each entry pairs a subnet mask with its network prefix in network byte order.
    private static let nonPublicIPv4: [(UInt32, UInt32)] = [
        (0xff000000, 0x00000000), // 0.0.0.0/8, this network
        (0xff000000, 0x0a000000), // 10.0.0.0/8, private
        (0xffc00000, 0x64400000), // 100.64.0.0/10, shared
        (0xff000000, 0x7f000000), // 127.0.0.0/8, loopback
        (0xffff0000, 0xa9fe0000), // 169.254.0.0/16, link-local
        (0xfff00000, 0xac100000), // 172.16.0.0/12, private
        (0xffffff00, 0xc0000000), // 192.0.0.0/24, protocol assignments
        (0xffffff00, 0xc0000200), // 192.0.2.0/24, documentation
        (0xffffff00, 0xc0586300), // 192.88.99.0/24, deprecated 6to4 relay
        (0xffff0000, 0xc0a80000), // 192.168.0.0/16, private
        (0xfffe0000, 0xc6120000), // 198.18.0.0/15, benchmarking
        (0xffffff00, 0xc6336400), // 198.51.100.0/24, documentation
        (0xffffff00, 0xcb007100), // 203.0.113.0/24, documentation
        (0xe0000000, 0xe0000000)  // 224.0.0.0/3, multicast and reserved
    ]

    private static let nonPublicIPv6: [(UInt32, UInt32)] = [
        (0xfffffe00, 0x20010000), // 2001::/23, protocol assignments
        (0xffffffff, 0x20010db8), // 2001:db8::/32, documentation
        (0xffff0000, 0x20020000), // 2002::/16, 6to4
        (0xfff00000, 0x3ff00000)  // 3ff0::/12, reserved and documentation
    ]

    private let resolver: Resolver?
    private let transport: Transport?

    init(resolver: Resolver? = nil, transport: Transport? = nil) {
        self.resolver = resolver
        self.transport = transport
    }

    func download(url: String, on context: ExecutionContext) async throws -> ByteBuffer {
        let application = context.application
        // Share one HTTP deadline across redirects and attempts to connect to different addresses.
        let deadline = NIODeadline.now() + Constants.remoteResourceRequestTimeout

        let resolve: Resolver = self.resolver ?? { host in
            guard let pool = application.remoteResourceDNSPool else {
                throw RemoteResourceDownloadError.unresolvedHost
            }

            try Task.checkCancellation()

            // Keep blocking name resolution off the pool used for file I/O.
            // The future-based overload avoids retaining cancellation IDs for work already running in SwiftNIO.
            let addresses = try await pool.runIfActive(eventLoop: context.eventLoop) {
                try self.resolveAddresses(host: host)
            }.get()

            try Task.checkCancellation()
            return addresses
        }
        let fetch: Transport = self.transport ?? { url, host, address, connectTimeout in
            try await self.fetch(
                url: url,
                host: host,
                address: address,
                connectTimeout: connectTimeout,
                deadline: deadline,
                on: application
            )
        }

        return try await self.download(url: url, resolve: resolve, fetch: fetch)
    }

    private func download(
        url: String,
        resolve: Resolver,
        fetch: Transport
    ) async throws -> ByteBuffer {
        var url = URL(string: url)

        for hop in 0...5 {
            try Task.checkCancellation()

            guard let target = url, let scheme = target.scheme?.lowercased(), scheme == "http" || scheme == "https",
                  let host = target.host, !host.isEmpty, target.user == nil, target.password == nil,
                  (1...65535).contains(target.port ?? (scheme == "https" ? 443 : 80)) else {
                throw RemoteResourceDownloadError.invalidURL
            }

            let literal = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))

            let addresses = if (try? SocketAddress(ipAddress: literal, port: 0)) != nil {
                [literal]
            } else {
                try await resolve(host)
            }

            guard let lastAddress = addresses.last else {
                throw RemoteResourceDownloadError.unresolvedHost
            }

            // Reject mixed DNS results before trying any address from the host.
            guard addresses.allSatisfy(isPublicAddress) else {
                throw RemoteResourceDownloadError.nonPublicAddress
            }

            let response = try await fetchFirstAvailable(url: target, host: host, addresses: addresses,
                                                         lastAddress: lastAddress, fetch: fetch)

            switch response.status.code {
            case 200..<300:

                guard let buffer = response.body, buffer.readableBytes > 0 else {
                    throw StorageError.emptyBody
                }
                return buffer
            case 301, 302, 303, 307, 308:

                guard hop < 5 else {
                    throw RemoteResourceDownloadError.tooManyRedirects
                }

                guard let location = response.headers.first(name: .location), !location.isEmpty,
                      let destination = URL(string: location, relativeTo: target)?.absoluteURL else {
                    throw RemoteResourceDownloadError.invalidRedirect
                }

                // The next iteration validates the redirect target before opening a connection.
                url = destination
            default:
                throw StorageError.downloadRemoteResourceFailed(response)
            }
        }

        throw RemoteResourceDownloadError.tooManyRedirects
    }

    private func fetchFirstAvailable(
        url: URL,
        host: String,
        addresses: [String],
        lastAddress: String,
        fetch: Transport
    ) async throws -> ClientResponse {
        // Keep connection attempts short while another verified address is available.
        for address in addresses.dropLast() {
            try Task.checkCancellation()

            do {
                return try await fetch(url, host, address, Constants.remoteResourceConnectFallbackTimeout)
            } catch let error as NIOTooManyBytesError {
                // The size limit applies to the resource, so do not download it again from another address.
                throw error
            } catch {
                continue
            }
        }

        try Task.checkCancellation()
        return try await fetch(url, host, lastAddress, nil)
    }

    private func fetch(
        url: URL,
        host: String,
        address: String,
        connectTimeout: TimeAmount?,
        deadline: NIODeadline,
        on application: Application
    ) async throws -> ClientResponse {
        // Keep redirect handling in the validation loop and connect directly to the verified IP.
        var configuration = HTTPClient.Configuration(
            redirectConfiguration: .disallow,
            timeout: .init(connect: connectTimeout, read: Constants.remoteResourceReadTimeout),
            proxy: nil
        )

        // The URL hostname still supplies the HTTP Host header and the TLS certificate name.
        configuration.dnsOverride[host] = address
        let client = HTTPClient(eventLoopGroup: application.eventLoopGroup, configuration: configuration)
        var request = HTTPClientRequest(url: url.absoluteString)
        request.headers.add(name: .userAgent, value: Constants.userAgent)

        let result: ClientResponse

        do {
            let response = try await client.execute(request, deadline: deadline)

            // Redirects and HTTP errors only need the status and headers.
            let body = if (200..<300).contains(response.status.code) {
                try await response.body.collect(upTo: Constants.remoteResourceSizeLimit)
            } else {
                nil as ByteBuffer?
            }
            result = ClientResponse(status: response.status, headers: response.headers, body: body)
        } catch {
            try? await client.shutdown()
            throw error
        }

        try await client.shutdown()
        return result
    }

    private func resolveAddresses(host: String) throws -> [String] {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC

        #if canImport(Glibc)
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        #else
        hints.ai_socktype = SOCK_STREAM
        #endif

        var result: UnsafeMutablePointer<addrinfo>?

        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else {
            throw RemoteResourceDownloadError.unresolvedHost
        }

        defer { freeaddrinfo(first) }

        var addresses: [String] = []
        var current: UnsafeMutablePointer<addrinfo>? = first

        while let entry = current {
            let info = entry.pointee
            current = info.ai_next

            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))

            guard let socketAddress = info.ai_addr,
                  getnameinfo(socketAddress, info.ai_addrlen, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 else {
                throw RemoteResourceDownloadError.unresolvedHost
            }

            let address = String(decoding: buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)

            if !addresses.contains(address) {
                addresses.append(address)
            }
        }

        return addresses
    }

    private func isPublicAddress(_ address: String) -> Bool {
        var ipv4 = in_addr()

        if inet_pton(AF_INET, address, &ipv4) == 1 {
            let value = UInt32(bigEndian: ipv4.s_addr)
            return !Self.nonPublicIPv4.contains { mask, prefix in value & mask == prefix }
        }

        var ipv6 = in6_addr()

        guard inet_pton(AF_INET6, address, &ipv6) == 1 else {
            return false
        }

        return withUnsafeBytes(of: &ipv6) { bytes in
            // Accept global unicast only, excluding special-purpose and transition prefixes.
            guard bytes[0] & 0xe0 == 0x20 else { return false }

            // The excluded IPv6 ranges need at most the first 32 bits for prefix matching.
            let prefix = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            return !Self.nonPublicIPv6.contains { mask, network in prefix & mask == network }
        }
    }
}
