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

@Suite("ActivityPub client JSON decoding")
struct ActivityPubClientJsonDecodingTests {
    @Test
    func `Invalid UTF8 should throw a decoding error without crashing`() throws {
        // Arrange
        let url = try #require(URL(string: "https://remote.example/actor"))
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        let data = Data([0xff])
        let client = ActivityPubClient()

        // Act
        let result = Result { try client.downloadJson(WebfingerDto.self, data: data, response: response) }

        // Assert
        #if DEBUG
        #expect(throws: NetworkError.self) { try result.get() }
        #else
        #expect(throws: DecodingError.self) { try result.get() }
        #endif
    }

    @Test
    func `Custom decoder error should be preserved with invalid UTF8 response`() throws {
        // Arrange
        let url = try #require(URL(string: "https://remote.example/actor"))
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        // JSONDecoder accepts UTF-16 JSON, but these bytes cannot be printed as UTF-8.
        let data = try #require("{}".data(using: .utf16))
        let client = ActivityPubClient()

        // Act
        let result = Result { try client.downloadJson(RejectingDocument.self, data: data, response: response) }

        // Assert
        #expect(throws: Rejection.expected) { try result.get() }
    }

    private enum Rejection: Error, Equatable {
        case expected
    }

    private struct RejectingDocument: Decodable {
        init(from decoder: Decoder) throws {
            throw Rejection.expected
        }
    }
}
