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

extension ControllersTests {
    
    @Suite("PushSubscriptions (PUT /push-subscriptions/:id)", .serialized, .tags(.pushSubscriptions))
    struct PushSubscriptionsUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Push subscription should be updated by authorized user")
        func pushSubscriptionShouldBeUpdatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laratorunek")
            let orginalPushSubscription = try await application.createPushSubscription(userId: user.requireID(),
                                                                                       endpoint: "https://endpoint000.com",
                                                                                       userAgentPublicKey: "111",
                                                                                       auth: "333")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint111.com",
                                                          userAgentPublicKey: "222",
                                                          auth: "444")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laratorunek", password: "p@ssword"),
                to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
                method: .PUT,
                body: pushSubscriptionDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let pushSubscription = try await application.getPushSubscription(endpoint: "https://endpoint111.com")
            #expect(pushSubscription?.userAgentPublicKey == "222", "Public key should be set correctly.")
            #expect(pushSubscription?.auth == "444", "Auth should be set correctly.")
        }
        
        @Test("Push subscription should not be updated if endpoint was not specified")
        func pushSubscriptionShouldNotBeUpdatedIfEndpointWasNotSpecified() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "trondtorunek")
            let orginalPushSubscription = try await application.createPushSubscription(userId: user.requireID(),
                                                                                       endpoint: "https://endpoint000.com",
                                                                                       userAgentPublicKey: "111",
                                                                                       auth: "333")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "",
                                                          userAgentPublicKey: "222",
                                                          auth: "444")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "trondtorunek", password: "p@ssword"),
                to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
                method: .PUT,
                data: pushSubscriptionDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("endpoint") == "is an invalid URL")
        }
        
        @Test("Push subscription should not be updated if endpoint is not correct")
        func pushSubscriptionShouldNotBeUpdatedIfEndpointIsNotCorrect() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robixatorunek")
            let orginalPushSubscription = try await application.createPushSubscription(userId: user.requireID(),
                                                                                       endpoint: "https://endpoint000.com",
                                                                                       userAgentPublicKey: "111",
                                                                                       auth: "333")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https:/endpoint000.com",
                                                          userAgentPublicKey: "222",
                                                          auth: "444")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robixatorunek", password: "p@ssword"),
                to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
                method: .PUT,
                data: pushSubscriptionDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("endpoint") == "is an invalid URL")
        }
        
        @Test("Push subscription should not be updated if user public key is empty")
        func pushSubscriptionShouldNotBeUpdatedIfUserPublicKeyIsEmpty() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "tredastorunek")
            let orginalPushSubscription = try await application.createPushSubscription(userId: user.requireID(),
                                                                                       endpoint: "https://endpoint000.com",
                                                                                       userAgentPublicKey: "111",
                                                                                       auth: "333")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint000.com",
                                                          userAgentPublicKey: "",
                                                          auth: "444")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "tredastorunek", password: "p@ssword"),
                to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
                method: .PUT,
                data: pushSubscriptionDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("userAgentPublicKey") == "is empty")
        }
        
        @Test("Push subscription should not be updated if auth is empty")
        func pushSubscriptionShouldNotBeUpdatedIfAuthIsEmpty() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "mariatorunek")
            let orginalPushSubscription = try await application.createPushSubscription(userId: user.requireID(),
                                                                                       endpoint: "https://endpoint000.com",
                                                                                       userAgentPublicKey: "111",
                                                                                       auth: "333")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint000.com",
                                                          userAgentPublicKey: "sss",
                                                          auth: "")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "mariatorunek", password: "p@ssword"),
                to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
                method: .PUT,
                data: pushSubscriptionDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("auth") == "is empty")
        }
        
        @Test("Not found should be returned for changing somebody else entity")
        func notFoundShouldBeReturnedForChangingSomebodyElseEntity() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "zenontorunek")
            _ = try await application.createUser(userName: "wiktortorunek")
            let orginalPushSubscription = try await application.createPushSubscription(userId: user1.requireID(),
                                                                                       endpoint: "https://endpoint000.com",
                                                                                       userAgentPublicKey: "111",
                                                                                       auth: "333")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint000.com",
                                                          userAgentPublicKey: "sss",
                                                          auth: "222")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "wiktortorunek", password: "p@ssword"),
                to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
                method: .PUT,
                body: pushSubscriptionDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorize should be returned for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "yoritorunek")
            let orginalPushSubscription = try await application.createPushSubscription(userId: user.requireID(),
                                                                                       endpoint: "https://endpoint000.com",
                                                                                       userAgentPublicKey: "111",
                                                                                       auth: "333")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint000.com",
                                                          userAgentPublicKey: "sss",
                                                          auth: "222")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
                method: .PUT,
                body: pushSubscriptionDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
