//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import Queues
import ActivityPubKit
import _CryptoExtras

final class UnfollowTests: CustomTestCase {
    
    func testUnfollowShouldSuccessWhenAllCorrectDataHasBeenApplied() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "vikibugs", generateKeys: true)
        let user2 = try await User.create(userName: "rickbugs", generateKeys: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        
        let activityDto = ActivityDto.unfollow(sourceActorId: user1.activityPubProfile, targetActorId: user2.activityPubProfile)
        let activityPubRequestDto = try ActivityPubRequestDto(cryptoService: CryptoService(),
                                                              privateKey: user1.privateKey!,
                                                              activity: activityDto,
                                                              basePath: "vernissage.photos",
                                                              version: "1.0.0",
                                                              actorId: user1.activityPubProfile)
        
        // Act.
        let queue = ActivityPubSharedInboxJob()
        try await queue.dequeue(SharedApplication.application().getQueueContext(queueName: .apSharedInbox), activityPubRequestDto)
        
        // Assert.
        let follow = try await Follow.get(sourceId: user1.requireID(), targetId: user2.requireID())
        XCTAssertNil(follow, "Follow must be deleted from local datbase")
    }
}
