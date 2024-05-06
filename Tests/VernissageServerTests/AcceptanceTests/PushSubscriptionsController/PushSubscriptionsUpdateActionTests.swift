//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class PushSubscriptionsUpdateActionTests: CustomTestCase {
    func testPushSubscriptionShouldBeUpdatedByAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "laratorunek")
        let orginalPushSubscription = try await PushSubscription.create(userId: user.requireID(),
                                                                        endpoint: "https://endpoint000.com",
                                                                        userAgentPublicKey: "111",
                                                                        auth: "333")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint111.com",
                                                      userAgentPublicKey: "222",
                                                      auth: "444")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "laratorunek", password: "p@ssword"),
            to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
            method: .PUT,
            body: pushSubscriptionDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be created (200).")
        let pushSubscription = try await PushSubscription.get(endpoint: "https://endpoint111.com")
        XCTAssertEqual(pushSubscription?.userAgentPublicKey, "222", "Public key should be set correctly.")
        XCTAssertEqual(pushSubscription?.auth, "444", "Auth should be set correctly.")
    }
    
    func testPushSubscriptionShouldNotBeUpdatedIfEndpointWasNotSpecified() async throws {

        // Arrange.
        let user = try await User.create(userName: "trondtorunek")
        let orginalPushSubscription = try await PushSubscription.create(userId: user.requireID(),
                                                                        endpoint: "https://endpoint000.com",
                                                                        userAgentPublicKey: "111",
                                                                        auth: "333")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "",
                                                      userAgentPublicKey: "222",
                                                      auth: "444")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "trondtorunek", password: "p@ssword"),
            to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
            method: .PUT,
            data: pushSubscriptionDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("endpoint"), "is an invalid URL")
    }
    
    func testPushSubscriptionShouldNotBeUpdatedIfEndpointIsNotCorrect() async throws {

        // Arrange.
        let user = try await User.create(userName: "robixatorunek")
        let orginalPushSubscription = try await PushSubscription.create(userId: user.requireID(),
                                                                        endpoint: "https://endpoint000.com",
                                                                        userAgentPublicKey: "111",
                                                                        auth: "333")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https:/endpoint000.com",
                                                      userAgentPublicKey: "222",
                                                      auth: "444")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "robixatorunek", password: "p@ssword"),
            to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
            method: .PUT,
            data: pushSubscriptionDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("endpoint"), "is an invalid URL")
    }
    
    func testPushSubscriptionShouldNotBeUpdatedIfUserPublicKeyIsEmpty() async throws {

        // Arrange.
        let user = try await User.create(userName: "tredastorunek")
        let orginalPushSubscription = try await PushSubscription.create(userId: user.requireID(),
                                                                        endpoint: "https://endpoint000.com",
                                                                        userAgentPublicKey: "111",
                                                                        auth: "333")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint000.com",
                                                      userAgentPublicKey: "",
                                                      auth: "444")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "tredastorunek", password: "p@ssword"),
            to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
            method: .PUT,
            data: pushSubscriptionDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("userAgentPublicKey"), "is empty")
    }

    func testPushSubscriptionShouldNotBeUpdatedIfAuthIsEmpty() async throws {

        // Arrange.
        let user = try await User.create(userName: "mariatorunek")
        let orginalPushSubscription = try await PushSubscription.create(userId: user.requireID(),
                                                                        endpoint: "https://endpoint000.com",
                                                                        userAgentPublicKey: "111",
                                                                        auth: "333")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint000.com",
                                                      userAgentPublicKey: "sss",
                                                      auth: "")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "mariatorunek", password: "p@ssword"),
            to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
            method: .PUT,
            data: pushSubscriptionDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("auth"), "is empty")
    }
    
    func testNotFoundShouldBeReturnedForChangingSomebodyElseEntity() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "zenontorunek")
        _ = try await User.create(userName: "wiktortorunek")
        let orginalPushSubscription = try await PushSubscription.create(userId: user1.requireID(),
                                                                        endpoint: "https://endpoint000.com",
                                                                        userAgentPublicKey: "111",
                                                                        auth: "333")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint000.com",
                                                      userAgentPublicKey: "sss",
                                                      auth: "222")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "wiktortorunek", password: "p@ssword"),
            to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
            method: .PUT,
            body: pushSubscriptionDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "yoritorunek")
        let orginalPushSubscription = try await PushSubscription.create(userId: user.requireID(),
                                                                        endpoint: "https://endpoint000.com",
                                                                        userAgentPublicKey: "111",
                                                                        auth: "333")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint000.com",
                                                      userAgentPublicKey: "sss",
                                                      auth: "222")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
            method: .PUT,
            body: pushSubscriptionDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
