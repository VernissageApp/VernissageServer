//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Foundation
import Testing

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct ActivityPubNoteIdentityTests {
    private let noteID = "https://remote.example/notes/1"

    @Test
    func `A public link imports the response from the canonical ID`() async throws {
        let url = try #require(URL(string: "https://remote.example/@alice/1?source=share#post"))
        let client = makeClient()

        let note = try await client.note(publicURL: url, activityPubProfile: "https://local.example/actor")

        #expect(note.id == "https://remote.example/users/alice/statuses/1")
        #expect(note.content == "Canonical content")
    }

    @Test
    func `A public HTTP link can resolve to a canonical HTTPS note on the same host`() async throws {
        let url = try #require(URL(string: "http://remote.example/legacy/1"))
        let client = makeClient()

        let note = try await client.note(publicURL: url, activityPubProfile: "https://local.example/actor")

        #expect(note.id == "https://remote.example/users/alice/statuses/1")
        #expect(note.content == "Canonical content")
    }

    @Test
    func `An import by ID rejects an HTTP to HTTPS origin change`() async throws {
        let url = try #require(URL(string: "http://remote.example/legacy/1"))
        let client = makeClient()

        await #expect(throws: NoteValidationError.responseOriginMismatch) {
            try await client.note(url: url, activityPubProfile: "https://local.example/actor")
        }
    }

    @Test
    func `A public HTTP link rejects an HTTPS response from a different host`() async throws {
        let url = try #require(URL(string: "http://remote.example/legacy/2"))
        let client = makeClient()

        await #expect(throws: NoteValidationError.responseOriginMismatch) {
            try await client.note(publicURL: url, activityPubProfile: "https://local.example/actor")
        }
    }

    @Test
    func `An import by ID does not resolve a public link`() async throws {
        let url = try #require(URL(string: "https://remote.example/@alice/1?source=share"))
        let client = makeClient()

        await #expect(throws: NoteValidationError.objectIdMismatch) {
            try await client.note(url: url, activityPubProfile: "https://local.example/actor")
        }
    }

    @Test
    func `A public link cannot resolve an ID on another origin`() async throws {
        let url = try #require(URL(string: "https://remote.example/@alice/2"))
        let client = makeClient()

        await #expect(throws: NoteValidationError.objectIdMismatch) {
            try await client.note(publicURL: url, activityPubProfile: "https://local.example/actor")
        }
    }

    @Test(arguments: ["https://remote.example/notes/1", "https://remote.example/objects/1"])
    func `Accepts a matching note served by the author's origin`(responseURL: String) throws {
        let author = "https://REMOTE.example:443/users/alice"
        let note = try decodeNote(id: noteID, author: author, responseURL: responseURL)

        #expect(note.id == noteID)
        #expect(note.attributedTo == author)
    }

    @Test
    func `Rejects a note with a different identifier on the same origin`() throws {
        #expect(throws: NoteValidationError.objectIdMismatch) {
            try decodeNote(id: "https://remote.example/notes/2",
                           author: "https://remote.example/users/alice",
                           responseURL: noteID)
        }
    }

    @Test(arguments: ["https://other.example/users/alice", "https://remote.example:8443/users/alice",
                      "http://remote.example/users/alice", "/users/alice"])
    func `Rejects an author outside the note origin`(author: String) throws {
        #expect(throws: NoteValidationError.authorOriginMismatch) {
            try decodeNote(id: noteID, author: author, responseURL: noteID)
        }
    }

    @Test(arguments: ["https://other.example/notes/1", "https://remote.example:8443/notes/1",
                      "http://remote.example/notes/1"])
    func `Rejects a response from another origin even when the note matches`(responseURL: String) throws {
        #expect(throws: NoteValidationError.responseOriginMismatch) {
            try decodeNote(id: noteID, author: "https://remote.example/users/alice", responseURL: responseURL)
        }
    }

    private func decodeNote(id: String, author: String, responseURL: String) throws -> NoteDto {
        let requestedURL = try #require(URL(string: noteID))
        let finalURL = try #require(URL(string: responseURL))
        let response = try #require(HTTPURLResponse(url: finalURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let data = try JSONEncoder().encode(["type": "Note", "id": id, "attributedTo": author])

        return try ActivityPubClient().decodeNote(data: data, response: response, requestedURL: requestedURL)
    }

    private func makeClient() -> ActivityPubClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NoteDiscoveryURLProtocol.self]
        return ActivityPubClient(privatePemKey: "test-key", userAgent: "Test client", host: "remote.example",
                                 urlSession: URLSession(configuration: configuration))
    }
}

private final class NoteDiscoveryURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let canonicalId = "https://remote.example/users/alice/statuses/1"
        let publicId = "https://remote.example/@alice/1?source=share"
        var responseURL = url.absoluteString
        var statusCode = 200
        let body: [String: String]
        switch url.absoluteString {
        case "http://remote.example/legacy/1":
            responseURL = publicId
            statusCode = 401
            body = [:]
        case "http://remote.example/legacy/2":
            responseURL = "https://other.example/@alice/2"
            body = [:]
        case publicId:
            body = ["id": canonicalId, "content": "Public response"]
        case canonicalId:
            body = ["id": canonicalId, "content": "Canonical content"]
        case "https://remote.example/@alice/2":
            body = ["id": "https://other.example/notes/2"]
        default:
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        guard let finalURL = URL(string: responseURL),
              let response = HTTPURLResponse(url: finalURL, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let note = body.merging(["type": "Note", "attributedTo": "https://remote.example/users/alice"]) { current, _ in current }
            let data = try JSONEncoder().encode(note)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
