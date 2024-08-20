//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class PushSubscriptionsListActionTests: CustomTestCase {
    func testListOfPushSubscriptionsShouldBeReturnedForUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robintonor")
        
        _ = try await PushSubscription.create(userId: user.requireID(),
                                              endpoint: "https://endpoint.com",
                                              userAgentPublicKey: "123",
                                              auth: "999")

        _ = try await PushSubscription.create(userId: user.requireID(),
                                              endpoint: "https://endpoint2.com",
                                              userAgentPublicKey: "123",
                                              auth: "999")
        
        // Act.
        let pushSubscriptions = try SharedApplication.application().getResponse(
            as: .user(userName: "robintonor", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .GET,
            decodeTo: PaginableResultDto<PushSubscriptionDto>.self
        )

        // Assert.
        XCTAssertNotNil(pushSubscriptions, "Push subscriptions should be returned.")
        XCTAssertTrue(pushSubscriptions.data.count > 0, "Some push subscriptions should be returned.")
    }
        
    func testOnlyUsersPushSubscriptionsShouldBeReturned() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "annatonor")
        let user2 = try await User.create(userName: "walentytonor")
        
        _ = try await PushSubscription.create(userId: user1.requireID(),
                                              endpoint: "https://endpoint1.com",
                                              userAgentPublicKey: "123",
                                              auth: "999")

        _ = try await PushSubscription.create(userId: user2.requireID(),
                                              endpoint: "https://endpoint2.com",
                                              userAgentPublicKey: "123",
                                              auth: "999")
        
        // Act.
        let pushSubscriptions = try SharedApplication.application().getResponse(
            as: .user(userName: "annatonor", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .GET,
            decodeTo: PaginableResultDto<PushSubscriptionDto>.self
        )

        // Assert.
        XCTAssertNotNil(pushSubscriptions, "Push subscriptions should be returned.")
        XCTAssertTrue(pushSubscriptions.data.count == 1, "Only current user push subscription should be returned.")
        XCTAssertEqual(pushSubscriptions.data.first?.endpoint, "https://endpoint1.com", "Push subscription is not created by current user.")
    }
    
    func testListOfPushSubscriptionsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/push-subscriptions", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
