//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubSharedAcceptTests: CustomTestCase {
    func testAcceptShouldSuccessWhenAllCorrectDataHasBeenApplied() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "vikigus", generateKeys: true)
        let user2 = try await User.create(userName: "rickgus", generateKeys: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: false)
        
        let acceptTarget = ActivityPub.Users.accept(user1.activityPubProfile,
                                                    user2.activityPubProfile,
                                                    user2.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost",
                                                    123,
                                                    "https://localhost/follow/212")
        
        // Act.
        _ = try SharedApplication.application().sendRequest(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: acceptTarget.headers?.getHTTPHeaders() ?? .init(),
            body: acceptTarget.httpBody!)
        
        // Assert.
        let follow = try await Follow.get(sourceId: user1.requireID(), targetId: user2.requireID())
        XCTAssertNotNil(follow, "Follow must exists local datbase.")
        XCTAssertTrue(follow!.approved, "Follow must be approved.")
    }
}
