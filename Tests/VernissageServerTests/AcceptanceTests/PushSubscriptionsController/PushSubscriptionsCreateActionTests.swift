//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class PushSubscriptionsCreateActionTests: CustomTestCase {
    func testPushSubscriptionShouldBeCreatedByAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "larauribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint11.com",
                                                      userAgentPublicKey: "123",
                                                      auth: "999")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "larauribg", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .POST,
            body: pushSubscriptionDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.created, "Response http status code should be created (201).")
        let pushSubscription = try await PushSubscription.get(endpoint: "https://endpoint11.com")
        XCTAssertEqual(pushSubscription?.userAgentPublicKey, "123", "Public key is should be set correctly.")
    }
    
    func testPushSubscriptionShouldNotBeCreatedIfEndpointWasNotSpecified() async throws {

        // Arrange.
        _ = try await User.create(userName: "tronduribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "",
                                                      userAgentPublicKey: "123",
                                                      auth: "999")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "tronduribg", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .POST,
            data: pushSubscriptionDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("endpoint"), "is an invalid URL")
    }
    
    func testPushSubscriptionShouldNotBeCreatedIfEndpointIsNotCorrect() async throws {

        // Arrange.
        _ = try await User.create(userName: "aferuribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http:/asss.com",
                                                      userAgentPublicKey: "123",
                                                      auth: "999")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "aferuribg", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .POST,
            data: pushSubscriptionDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("endpoint"), "is an invalid URL")
    }

    func testPushSubscriptionShouldNotBeCreatedIfUserAgentPublicKeyIsEmpty() async throws {

        // Arrange.
        _ = try await User.create(userName: "robxuribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http://asss.com",
                                                      userAgentPublicKey: "",
                                                      auth: "999")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "robxuribg", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .POST,
            data: pushSubscriptionDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("userAgentPublicKey"), "is empty")
    }

    
    func testPushSubscriptionShouldNotBeCreatedIfAuthIsEmpty() async throws {

        // Arrange.
        _ = try await User.create(userName: "tobiaszuribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http://asss.com",
                                                      userAgentPublicKey: "asdasd",
                                                      auth: "")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "tobiaszuribg", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .POST,
            data: pushSubscriptionDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("auth"), "is empty")
    }

    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "yoriuuribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http://asss.com",
                                                      userAgentPublicKey: "asdasd",
                                                      auth: "000")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/push-subscriptions",
            method: .POST,
            body: pushSubscriptionDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
