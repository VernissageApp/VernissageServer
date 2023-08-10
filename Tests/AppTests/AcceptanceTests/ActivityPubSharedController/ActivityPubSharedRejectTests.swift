//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubSharedRejectTests: CustomTestCase {
    func testAcceptShouldSuccessWhenAllCorrectDataHasBeenApplied() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "vikihorn", generateKeys: true)
        let user2 = try await User.create(userName: "rickhorn", generateKeys: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: false)
        
        let rejectTarget = ActivityPub.Users.reject(user1.activityPubProfile,
                                                    user2.activityPubProfile,
                                                    user2.privateKey!,
                                                    "/shared/inbox",
                                                    "(Vernissage/1.0)",
                                                    "localhost",
                                                    123,
                                                    "https://localhost/follow/212")
        
        // Act.
        _ = try SharedApplication.application().sendRequest(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: rejectTarget.headers?.getHTTPHeaders() ?? .init(),
            body: rejectTarget.httpBody!)
        
        // Assert.
        let follow = try await Follow.get(sourceId: user1.requireID(), targetId: user2.requireID())
        XCTAssertNil(follow, "Follow must be deleted from local datbase.")
    }
}
