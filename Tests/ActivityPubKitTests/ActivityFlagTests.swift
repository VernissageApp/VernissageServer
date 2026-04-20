//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Testing
import Foundation

@Suite("Activity Flag")
struct ActivityFlagTests {
    let decoder = JSONDecoder()
    
    @Test
    func `Flag activity should deserialize with content and multiple reported objects`() throws {
        // Act.
        let activityDto = try decoder.decode(ActivityDto.self, from: ActivityFlagFixtures.flagJson.data(using: .utf8)!)
        
        // Assert.
        #expect(activityDto.id == ActivityFlagFixtures.expectedFlagActivityId)
        #expect(activityDto.type == .flag)
        #expect(activityDto.actor.actorIds() == ActivityFlagFixtures.expectedFlagActorIds)
        #expect(activityDto.object.objects().map(\.id) == ActivityFlagFixtures.expectedFlagObjectIds)
        #expect(activityDto.to?.actorIds() == ActivityFlagFixtures.expectedFlagToActorIds)
        #expect(activityDto.content == ActivityFlagFixtures.expectedFlagContent)
    }
    
    @Test
    func `Flag target should create activity for reported actor`() throws {
        // Arrange.
        let target = ActivityPub.Flag.create(
            "1",
            "https://vernissage.example/actor",
            ActivityFlagFixtures.reportedActorId,
            [],
            nil,
            "private-key",
            "/inbox",
            "Vernissage",
            "remote.example"
        )
        
        // Act.
        let jsonData = try #require(target.httpBody)
        
        // Assert.
        #expect(ActivityFlagFixtures.expectedReportedActorOnlyJson == String(data: jsonData, encoding: .utf8)!)
    }
    
    @Test
    func `Flag target should create activity for reported actor and objects`() throws {
        // Arrange.
        let target = ActivityPub.Flag.create(
            "2",
            "https://vernissage.example/actor",
            ActivityFlagFixtures.reportedActorId,
            ActivityFlagFixtures.reportedObjectIds,
            ActivityFlagFixtures.reportedContent,
            "private-key",
            "/shared/inbox",
            "Vernissage",
            "remote.example"
        )
        
        // Act.
        let jsonData = try #require(target.httpBody)
        
        // Assert.
        #expect(ActivityFlagFixtures.expectedReportedActorAndObjectsJson == String(data: jsonData, encoding: .utf8)!)
    }
}
