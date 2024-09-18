//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

@Suite("POST /", .serialized, .tags(.pushSubscriptions))
struct PushSubscriptionsCreateActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Push subscription should be created by authorized user")
    func pushSubscriptionShouldBeCreatedByAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "larauribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint11.com",
                                                      userAgentPublicKey: "123",
                                                      auth: "999")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "larauribg", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .POST,
            body: pushSubscriptionDto
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
        let pushSubscription = try await application.getPushSubscription(endpoint: "https://endpoint11.com")
        #expect(pushSubscription?.userAgentPublicKey == "123", "Public key is should be set correctly.")
    }
    
    @Test("Push subscription should not be created if endpoin wWas not specified")
    func pushSubscriptionShouldNotBeCreatedIfEndpointWasNotSpecified() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "tronduribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "",
                                                      userAgentPublicKey: "123",
                                                      auth: "999")
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "tronduribg", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .POST,
            data: pushSubscriptionDto
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("endpoint") == "is an invalid URL")
    }
    
    @Test("Push subscription should not be created if endpoint is not correct")
    func pushSubscriptionShouldNotBeCreatedIfEndpointIsNotCorrect() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "aferuribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http:/asss.com",
                                                      userAgentPublicKey: "123",
                                                      auth: "999")
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "aferuribg", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .POST,
            data: pushSubscriptionDto
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("endpoint") == "is an invalid URL")
    }

    @Test("Push subscription should not be created if user agent public key is empty")
    func pushSubscriptionShouldNotBeCreatedIfUserAgentPublicKeyIsEmpty() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "robxuribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http://asss.com",
                                                      userAgentPublicKey: "",
                                                      auth: "999")
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "robxuribg", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .POST,
            data: pushSubscriptionDto
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("userAgentPublicKey") == "is empty")
    }

    @Test("Push subscription should not be created if auth is empty")
    func pushSubscriptionShouldNotBeCreatedIfAuthIsEmpty() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "tobiaszuribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http://asss.com",
                                                      userAgentPublicKey: "asdasd",
                                                      auth: "")
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "tobiaszuribg", password: "p@ssword"),
            to: "/push-subscriptions",
            method: .POST,
            data: pushSubscriptionDto
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("auth") == "is empty")
    }

    @Test("Unauthorize should be returned for not authorized user")
    func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "yoriuuribg")
        let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http://asss.com",
                                                      userAgentPublicKey: "asdasd",
                                                      auth: "000")
        
        // Act.
        let response = try application.sendRequest(
            to: "/push-subscriptions",
            method: .POST,
            body: pushSubscriptionDto
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
