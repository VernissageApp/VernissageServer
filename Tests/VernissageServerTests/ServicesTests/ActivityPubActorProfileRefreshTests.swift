//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Foundation
import Synchronization
import Testing
import Vapor

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("ActivityPub actor profile refresh")
struct ActivityPubActorProfileRefreshTests {
    @Test
    func `Refresh rejects a document declaring another stored actor ID`() async throws {
        // Arrange
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let requestedProfile = fixture.origin + "/actors/bob"
        let response = try fixture.stubResponse(requestedURL: requestedProfile, declaring: fixture.actorID)

        // Act
        let result = try await fixture.service.refreshRemoteUser(activityPubProfile: requestedProfile, on: fixture.context)

        // Assert
        #expect(response.requestURL.withLock { $0 } == requestedProfile)
        #expect(result == nil)
        let requestedActor = try await fixture.context.services.usersService.get(activityPubProfile: requestedProfile, on: fixture.context.db)
        #expect(requestedActor == nil)
        try await fixture.assertOriginalProfile()
    }

    @Test
    func `Refresh updates the key and inboxes when the actor ID matches`() async throws {
        // Arrange
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let response = try fixture.stubResponse(requestedURL: fixture.actorID, declaring: fixture.actorID)

        // Act
        let result = try await fixture.service.refreshRemoteUser(activityPubProfile: fixture.actorID, on: fixture.context)

        // Assert
        #expect(response.requestURL.withLock { $0 } == fixture.actorID)
        #expect(result?.id == fixture.user.id)
        let storedUser = try await fixture.loadStoredUser()
        #expect(storedUser.publicKey == fixture.publicKey)
        #expect(storedUser.userInbox == fixture.inbox)
        #expect(storedUser.sharedInbox == fixture.sharedInbox)
    }

    private struct Fixture {
        let host: String
        let origin: String
        let actorID: String
        let user: User
        let publicKey: String
        let context: ExecutionContext
        let service: ActivityPubDownloadUserService
        private let session: URLSession

        var inbox: String { origin + "/inbox" }
        var sharedInbox: String { origin + "/shared-inbox" }

        init() async throws {
            let application = try await ApplicationManager.shared.application()
            let host = "profile-\(UUID().uuidString.lowercased().prefix(12)).example"
            let origin = "https://\(host)"
            let actorID = origin + "/actors/alice"
            let user = User(id: application.services.snowflakeService.generate(),
                            type: .person,
                            url: origin + "/@alice",
                            isLocal: false,
                            userName: "alice@\(host)",
                            account: "alice@\(host)",
                            activityPubProfile: actorID,
                            locale: "en_US",
                            publicKey: "original key",
                            isApproved: true,
                            sharedInbox: origin + "/original-shared-inbox",
                            userInbox: origin + "/original-inbox")
            try await user.save(on: application.db)
            let (_, publicKey) = try application.services.cryptoService.generateKeys()

            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [ActorProfileURLProtocol.self]
            let session = URLSession(configuration: configuration)

            self.host = host
            self.origin = origin
            self.actorID = actorID
            self.user = user
            self.publicKey = publicKey
            self.context = Request(application: application, on: application.eventLoopGroup.next()).executionContext
            self.service = ActivityPubDownloadUserService(urlSession: session)
            self.session = session
        }

        func stubResponse(requestedURL: String, declaring declaredProfile: String) throws -> ActorProfileURLProtocol.Fixture {
            let body = try JSONSerialization.data(withJSONObject: [
                "@context": "https://www.w3.org/ns/activitystreams",
                "type": "Person",
                "id": declaredProfile,
                "preferredUsername": "alice",
                "url": declaredProfile,
                "inbox": inbox,
                "outbox": origin + "/outbox",
                "endpoints": ["sharedInbox": sharedInbox],
                "publicKey": ["id": declaredProfile + "#main-key", "owner": declaredProfile, "publicKeyPem": publicKey]
            ])
            let response = ActorProfileURLProtocol.Fixture(url: try #require(URL(string: requestedURL)), body: body)
            ActorProfileURLProtocol.fixtures.withLock { $0[host] = response }
            return response
        }

        func loadStoredUser() async throws -> User {
            try #require(try await User.find(user.requireID(), on: context.db))
        }

        func assertOriginalProfile() async throws {
            let storedUser = try await loadStoredUser()
            #expect(storedUser.activityPubProfile == actorID)
            #expect(storedUser.publicKey == user.publicKey)
            #expect(storedUser.userInbox == user.userInbox)
            #expect(storedUser.sharedInbox == user.sharedInbox)
        }

        func tearDown() {
            session.invalidateAndCancel()
            ActorProfileURLProtocol.fixtures.withLock { $0[host] = nil }
        }
    }
}

private final class ActorProfileURLProtocol: URLProtocol {
    final class Fixture: Sendable {
        let url: URL
        let body: Data
        let requestURL = Mutex<String?>(nil)

        init(url: URL, body: Data) {
            self.url = url
            self.body = body
        }
    }

    static let fixtures = Mutex<[String: Fixture]>([:])

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() { }

    override func startLoading() {
        guard let url = request.url, let host = url.host,
              let fixture = Self.fixtures.withLock({ $0[host] }),
              url == fixture.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        fixture.requestURL.withLock { $0 = url.absoluteString }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: fixture.body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
