//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Foundation
import Testing

@Suite("ObjectDto deserialization")
struct ObjectDtoDeserializationTests {

    @Test
    func `Announce with context should deserialize as AnnouceDto`() throws {
        // Arrange.
        let json = """
        {
          "@context": "https://www.w3.org/ns/activitystreams",
          "id": "https://example.com/activities/announce",
          "type": "Announce",
          "actor": "https://example.com/actors/alice",
          "object": "https://example.com/statuses/1"
        }
        """

        // Act.
        let object = try JSONDecoder().decode(ObjectDto.self, from: Data(json.utf8))

        // Assert.
        let announce = try #require(object.object as? AnnouceDto)
        #expect(announce.object?.objects().first?.id == "https://example.com/statuses/1")
    }

    @Test
    func `Like with context should deserialize as LikeDto`() throws {
        // Arrange.
        let json = """
        {
          "@context": "https://www.w3.org/ns/activitystreams",
          "id": "https://example.com/activities/like",
          "type": "Like",
          "actor": "https://example.com/actors/alice",
          "object": "https://example.com/statuses/1"
        }
        """

        // Act.
        let object = try JSONDecoder().decode(ObjectDto.self, from: Data(json.utf8))

        // Assert.
        let like = try #require(object.object as? LikeDto)
        #expect(like.object?.objects().first?.id == "https://example.com/statuses/1")
    }
}
