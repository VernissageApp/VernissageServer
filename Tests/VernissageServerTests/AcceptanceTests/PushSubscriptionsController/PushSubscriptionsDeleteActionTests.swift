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
    
    @Suite("PushSubscriptions (DELETE /push-subscriptions/:id)", .serialized, .tags(.pushSubscriptions))
    struct PushSubscriptionsDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Push subscriptions should be deleted by authorized user")
        func pushSubscriptionsShouldBeDeletedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laratvix")
            let orginalPushSubscription = try await application.createPushSubscription(userId: user.requireID(),
                                                                                       endpoint: "https://endpointx1x1x1.com",
                                                                                       userAgentPublicKey: "111",
                                                                                       auth: "333")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "laratvix", password: "p@ssword"),
                to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let pushSubscription = try await application.getPushSubscription(endpoint: "https://endpointx1x1x1.com")
            #expect(pushSubscription == nil, "Instance blocked domain should be deleted.")
        }
        
        @Test("Not found should be returned when user is deleting somebody else entity")
        func notFoundShouldBeReturnedWhenUserIsDeletingSomebodyElseEntity() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "zenontvix")
            _ = try await application.createUser(userName: "wiktortvix")
            let orginalPushSubscription = try await application.createPushSubscription(userId: user1.requireID(),
                                                                                       endpoint: "https://endpoint000.com",
                                                                                       userAgentPublicKey: "111",
                                                                                       auth: "333")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "wiktortvix", password: "p@ssword"),
                to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorize should be returned for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "yorigtvix")
            let orginalPushSubscription = try await application.createPushSubscription(userId: user.requireID(),
                                                                                       endpoint: "https://endpoint000.com",
                                                                                       userAgentPublicKey: "111",
                                                                                       auth: "333")
            
            // Act.
            let response = try application.sendRequest(
                to: "/push-subscriptions/" + (orginalPushSubscription.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
