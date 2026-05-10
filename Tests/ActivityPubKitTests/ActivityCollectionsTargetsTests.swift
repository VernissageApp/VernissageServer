//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Testing
import Foundation

@Suite("Activity Collections")
struct ActivityCollectionsTests {
    private let decoder = JSONDecoder()

    @Test
    func `Get collection target should use GET and no body`() throws {
        // Arrange.
        let target = ActivityPub.Collections.get("https://example.com/users/alice",
                                                 "private-key",
                                                 "/users/alice/collections/featured",
                                                 "Vernissage",
                                                 "example.com")

        // Assert.
        #expect(target.method == .get)
        #expect(target.httpBody == nil)
        #expect(target.headers?[.signature] != nil)
    }

    @Test
    func `Add collection target should serialize Add activity`() throws {
        // Arrange.
        let objectId = "https://remote.example/users/bob/statuses/123"
        let actorId = "https://example.com/users/alice"
        let targetId = "https://example.com/users/alice/collections/featured"

        let target = ActivityPub.Collections.add(objectId,
                                                 actorId,
                                                 targetId,
                                                 "private-key",
                                                 "/users/bob/inbox",
                                                 "Vernissage",
                                                 "remote.example",
                                                 1)

        // Act.
        let body = try #require(target.httpBody)
        let activity = try decoder.decode(ActivityDto.self, from: body)

        // Assert.
        #expect(target.method == .post)
        #expect(activity.type == .add)
        #expect(activity.id == "\(actorId)#featured/1/add")
        #expect(activity.actor.actorIds().first == actorId)
        #expect(activity.object.objects().first?.id == objectId)
        #expect(activity.target?.actorIds().first == targetId)
    }

    @Test
    func `Remove collection target should serialize Remove activity`() throws {
        // Arrange.
        let objectId = "https://remote.example/users/bob/statuses/456"
        let actorId = "https://example.com/users/alice"
        let targetId = "https://example.com/users/alice/collections/featured"

        let target = ActivityPub.Collections.remove(objectId,
                                                    actorId,
                                                    targetId,
                                                    "private-key",
                                                    "/users/bob/inbox",
                                                    "Vernissage",
                                                    "remote.example",
                                                    2)

        // Act.
        let body = try #require(target.httpBody)
        let activity = try decoder.decode(ActivityDto.self, from: body)

        // Assert.
        #expect(target.method == .post)
        #expect(activity.type == .remove)
        #expect(activity.id == "\(actorId)#featured/2/remove")
        #expect(activity.actor.actorIds().first == actorId)
        #expect(activity.object.objects().first?.id == objectId)
        #expect(activity.target?.actorIds().first == targetId)
    }
}
