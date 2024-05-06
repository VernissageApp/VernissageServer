//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class PushSubscriptionsDeleteActionTests: CustomTestCase {
    func testPushSubscriptionsShouldBeDeletedByAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "laratvix")
        let orginalPushSubscription = try await PushSubscription.create(userId: user.requireID(),
                                                                        endpoint: "https://endpointx1x1x1.com",
                                                                        userAgentPublicKey: "111",
                                                                        auth: "333")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "laratvix", password: "p@ssword"),
            to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be created (200).")
        let pushSubscription = try await PushSubscription.get(endpoint: "https://endpointx1x1x1.com")
        XCTAssertNil(pushSubscription, "Instance blocked domain should be deleted.")
    }
    
    func testNotFoundShouldBeReturnedWhenUserIsDeletingSomebodyElseEntity() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "zenontvix")
        _ = try await User.create(userName: "wiktortvix")
        let orginalPushSubscription = try await PushSubscription.create(userId: user1.requireID(),
                                                                        endpoint: "https://endpoint000.com",
                                                                        userAgentPublicKey: "111",
                                                                        auth: "333")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "wiktortvix", password: "p@ssword"),
            to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "yorigtvix")
        let orginalPushSubscription = try await PushSubscription.create(userId: user.requireID(),
                                                                        endpoint: "https://endpoint000.com",
                                                                        userAgentPublicKey: "111",
                                                                        auth: "333")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
