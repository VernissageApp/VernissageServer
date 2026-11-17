//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Foundation
import Testing

struct DirectMessageDeleteTargetsTests {
    @Test
    func `Private Delete addresses only explicit actors`() throws {
        // Arrange.
        let actor = "https://local.example/actors/alice"
        let object = "https://local.example/statuses/123"
        let recipients = ["https://remote.example/actors/bob", "https://other.example/actors/carol"]
        let target = ActivityPub.Notes.delete(actor, object, "private-key", "/actors/bob/inbox",
                                             "Vernissage", "remote.example", recipients)

        // Act.
        let body = try #require(target.httpBody)
        let activity = try JSONDecoder().decode(ActivityDto.self, from: body)

        // Assert.
        #expect(activity.type == .delete)
        #expect(activity.actor.actorIds() == [actor])
        #expect(activity.to?.actorIds() == recipients)
        #expect(activity.object.objects().first?.id == object)
        #expect(String(decoding: body, as: UTF8.self).contains("activitystreams#Public") == false)
    }

    @Test
    func `Public Delete keeps its existing public audience`() throws {
        // Arrange.
        let target = ActivityPub.Notes.delete("https://local.example/actors/alice", "https://local.example/statuses/123",
                                             "private-key", "/shared/inbox", "Vernissage", "remote.example")

        // Act.
        let activity = try JSONDecoder().decode(ActivityDto.self, from: #require(target.httpBody))

        // Assert.
        #expect(activity.to?.actorIds() == ["https://www.w3.org/ns/activitystreams#Public"])
    }
}
