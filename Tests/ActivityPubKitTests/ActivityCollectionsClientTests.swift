//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Testing
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("Activity Collections Client", .serialized)
struct ActivityCollectionsClientTests {
    @Test
    func `featuredCollectionPageData should decode ordered collection`() async throws {
        // Arrange.
        let body =
"""
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "type": "OrderedCollection",
  "id": "https://remote.example/users/alice/collections/featured",
  "totalItems": 2,
  "first": "https://remote.example/users/alice/collections/featured?page=true"
}
"""
        let url = try #require(URL(string: "https://remote.example/users/alice/collections/featured"))
        let session = TestURLProtocol.session(body: body)
        let client = ActivityPubClient(privatePemKey: "private-key",
                                       userAgent: "Vernissage",
                                       host: "remote.example",
                                       urlSession: session)

        // Act.
        let pageData = try await client.featuredCollectionPageData(url: url, activityPubProfile: "https://example.com/users/system")

        // Assert.
        #expect(pageData.orderedItems.isEmpty)
        #expect(pageData.first == "https://remote.example/users/alice/collections/featured?page=true")
        #expect(pageData.next == nil)
    }

    @Test
    func `featuredCollectionPageData should decode ordered collection page`() async throws {
        // Arrange.
        let body =
"""
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "type": "OrderedCollectionPage",
  "id": "https://remote.example/users/alice/collections/featured?page=true",
  "totalItems": 2,
  "partOf": "https://remote.example/users/alice/collections/featured",
  "next": "https://remote.example/users/alice/collections/featured?page=true&min_id=1",
  "orderedItems": [
    "https://remote.example/users/alice/statuses/1",
    "https://remote.example/users/alice/statuses/2"
  ]
}
"""
        let url = try #require(URL(string: "https://remote.example/users/alice/collections/featured?page=true"))
        let session = TestURLProtocol.session(body: body)
        let client = ActivityPubClient(privatePemKey: "private-key",
                                       userAgent: "Vernissage",
                                       host: "remote.example",
                                       urlSession: session)

        // Act.
        let pageData = try await client.featuredCollectionPageData(url: url, activityPubProfile: "https://example.com/users/system")

        // Assert.
        #expect(pageData.orderedItems.count == 2)
        #expect(pageData.orderedItems.first == "https://remote.example/users/alice/statuses/1")
        #expect(pageData.next == "https://remote.example/users/alice/collections/featured?page=true&min_id=1")
    }

    @Test
    func `addToFeatured should send POST with Add activity body`() async throws {
        // Arrange.
        let inboxUrl = try #require(URL(string: "https://remote.example/inbox"))
        let session = TestURLProtocol.session(body: "{}")
        let client = ActivityPubClient(privatePemKey: "private-key",
                                       userAgent: "Vernissage",
                                       host: "remote.example",
                                       urlSession: session)

        // Act.
        try await client.addToFeatured(objectId: "https://remote.example/users/alice/statuses/1",
                                       actorId: "https://example.com/users/alice",
                                       targetId: "https://example.com/users/alice/collections/featured",
                                       on: inboxUrl,
                                       withId: 100)

        // Assert.
        let request = try #require(TestURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: Header.digest.rawValue) != nil)
        let signatureHeader = request.value(forHTTPHeaderField: Header.signature.rawValue) ?? ""
        #expect(signatureHeader.contains("headers=\"(request-target) host date digest\""))
    }

    @Test
    func `removeFromFeatured should send POST with Remove activity body`() async throws {
        // Arrange.
        let inboxUrl = try #require(URL(string: "https://remote.example/inbox"))
        let session = TestURLProtocol.session(body: "{}")
        let client = ActivityPubClient(privatePemKey: "private-key",
                                       userAgent: "Vernissage",
                                       host: "remote.example",
                                       urlSession: session)

        // Act.
        try await client.removeFromFeatured(objectId: "https://remote.example/users/alice/statuses/1",
                                            actorId: "https://example.com/users/alice",
                                            targetId: "https://example.com/users/alice/collections/featured",
                                            on: inboxUrl,
                                            withId: 101)

        // Assert.
        let request = try #require(TestURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: Header.digest.rawValue) != nil)
        let signatureHeader = request.value(forHTTPHeaderField: Header.signature.rawValue) ?? ""
        #expect(signatureHeader.contains("headers=\"(request-target) host date digest\""))
    }
}

final class TestURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody = Data()
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static func session(body: String) -> URLSession {
        Self.responseBody = body.data(using: .utf8) ?? Data()
        Self.lastRequest = nil

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Self.self]
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5

        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request

        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        client?.urlProtocol(self, didReceive: response!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
    }
}
