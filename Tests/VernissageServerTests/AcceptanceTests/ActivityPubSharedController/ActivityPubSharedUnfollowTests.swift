//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubSharedUnfollowTests: CustomTestCase {
    func testUnfollowShouldSuccessWhenAllCorrectDataHasBeenApplied() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "vikibugs", generateKeys: true)
        let user2 = try await User.create(userName: "rickbugs", generateKeys: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        
        let followTarget = ActivityPub.Users.unfollow(user1.activityPubProfile,
                                                      user2.activityPubProfile,
                                                      user1.privateKey!,
                                                      "/shared/inbox",
                                                      Constants.userAgent,
                                                      "localhost",
                                                      123)
        
        // Act.
        _ = try SharedApplication.application().sendRequest(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: followTarget.headers?.getHTTPHeaders() ?? .init(),
            body: followTarget.httpBody!)
        
        // Assert.
        let follow = try await Follow.get(sourceId: user1.requireID(), targetId: user2.requireID())
        XCTAssertNil(follow, "Follow must be deleted from local datbase")
    }
}
