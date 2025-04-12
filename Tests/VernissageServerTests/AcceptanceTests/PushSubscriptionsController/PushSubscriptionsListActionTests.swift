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
    
    @Suite("PushSubscriptions (GET /push-subscriptions)", .serialized, .tags(.pushSubscriptions))
    struct PushSubscriptionsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of push subscriptions should be returned for user")
        func listOfPushSubscriptionsShouldBeReturnedForUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robintonor")
            
            _ = try await application.createPushSubscription(userId: user.requireID(),
                                                             endpoint: "https://endpoint.com",
                                                             userAgentPublicKey: "123",
                                                             auth: "999")
            
            _ = try await application.createPushSubscription(userId: user.requireID(),
                                                             endpoint: "https://endpoint2.com",
                                                             userAgentPublicKey: "123",
                                                             auth: "999")
            
            // Act.
            let pushSubscriptions = try await application.getResponse(
                as: .user(userName: "robintonor", password: "p@ssword"),
                to: "/push-subscriptions",
                method: .GET,
                decodeTo: PaginableResultDto<PushSubscriptionDto>.self
            )
            
            // Assert.
            #expect(pushSubscriptions.data.count > 0, "Some push subscriptions should be returned.")
        }
        
        @Test("Only users push subscriptions should be returned")
        func onlyUsersPushSubscriptionsShouldBeReturned() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "annatonor")
            let user2 = try await application.createUser(userName: "walentytonor")
            
            _ = try await application.createPushSubscription(userId: user1.requireID(),
                                                             endpoint: "https://endpoint1.com",
                                                             userAgentPublicKey: "123",
                                                             auth: "999")
            
            _ = try await application.createPushSubscription(userId: user2.requireID(),
                                                             endpoint: "https://endpoint2.com",
                                                             userAgentPublicKey: "123",
                                                             auth: "999")
            
            // Act.
            let pushSubscriptions = try await application.getResponse(
                as: .user(userName: "annatonor", password: "p@ssword"),
                to: "/push-subscriptions",
                method: .GET,
                decodeTo: PaginableResultDto<PushSubscriptionDto>.self
            )
            
            // Assert.
            #expect(pushSubscriptions.data.count == 1, "Only current user push subscription should be returned.")
            #expect(pushSubscriptions.data.first?.endpoint == "https://endpoint1.com", "Push subscription is not created by current user.")
        }
        
        @Test("List of push subscriptions should not be returned when user is not authorized")
        func listOfPushSubscriptionsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/push-subscriptions", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
