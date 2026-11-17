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
    
    @Suite("PushSubscriptions (POST /push-subscriptions)", .serialized, .tags(.pushSubscriptions))
    struct PushSubscriptionsCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Push subscription should be created by authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "larauribg")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "https://endpoint11.com",
                                                          userAgentPublicKey: "123",
                                                          auth: "999")
            
            // Act.
            let response = try await application.sendRequest(
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
        
        @Test
        func `Push subscription should not be created if endpoin wWas not specified`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "tronduribg")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "",
                                                          userAgentPublicKey: "123",
                                                          auth: "999")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
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
        
        @Test
        func `Push subscription should not be created if endpoint is not correct`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "aferuribg")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http:/asss.com",
                                                          userAgentPublicKey: "123",
                                                          auth: "999")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
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
        
        @Test
        func `Push subscription should not be created if user agent public key is empty`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "robxuribg")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http://asss.com",
                                                          userAgentPublicKey: "",
                                                          auth: "999")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
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
        
        @Test
        func `Push subscription should not be created if auth is empty`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "tobiaszuribg")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http://asss.com",
                                                          userAgentPublicKey: "asdasd",
                                                          auth: "")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
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
        
        @Test
        func `Unauthorize should be returned for not authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "yoriuuribg")
            let pushSubscriptionDto = PushSubscriptionDto(endpoint: "http://asss.com",
                                                          userAgentPublicKey: "asdasd",
                                                          auth: "000")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/push-subscriptions",
                method: .POST,
                body: pushSubscriptionDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }

        @Test
        func `Direct message push preference can be disabled independently`() async throws {
            // Arrange.
            let user = try await application.createDirectMessageUser()
            var dto = PushSubscriptionDto(endpoint: "https://example.com/push/" + UUID().uuidString,
                                          userAgentPublicKey: "key", auth: "secret")
            dto.webPushDirectMessageEnabled = false

            // Act.
            let result = try await application.getResponse(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/push-subscriptions",
                method: .POST,
                data: dto,
                decodeTo: PushSubscriptionDto.self)

            let subscription = try #require(try await application.getPushSubscription(endpoint: dto.endpoint))

            // Assert.
            #expect(result.webPushDirectMessageEnabled == false)
            #expect(subscription.isEnabled(type: .directMessage) == false)
            #expect(subscription.isEnabled(type: .mention))
            #expect(subscription.isEnabled(type: .newComment))
        }

        @Test
        func `Missing direct message push preference defaults to enabled for older clients`() async throws {
            // Arrange.
            let user = try await application.createDirectMessageUser()
            var dto = PushSubscriptionDto(endpoint: "https://example.com/push/" + UUID().uuidString,
                                          userAgentPublicKey: "key", auth: "secret")
            dto.webPushDirectMessageEnabled = nil

            // Act.
            let result = try await application.getResponse(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/push-subscriptions",
                method: .POST,
                data: dto,
                decodeTo: PushSubscriptionDto.self)

            // Assert.
            #expect(result.webPushDirectMessageEnabled == true)
        }
    }
}
