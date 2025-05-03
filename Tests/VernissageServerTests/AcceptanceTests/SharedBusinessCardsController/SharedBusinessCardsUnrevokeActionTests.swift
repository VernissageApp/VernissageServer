//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("SharedBusinessCards (POST /shared-business-cards/:id/unrevoke)", .serialized, .tags(.sharedBusinessCards))
    struct SharedBusinessCardsUnrevokeActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Shared business card should be unrevoked by authorized user")
        func sharedBusinessCardShouldBeUnrevokedByAuthoriedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorferdix")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia", revokedAt: Date())
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "wictorferdix", password: "p@ssword"),
                to: "/shared-business-cards/" + (sharedBusinessCard.stringId() ?? "") + "/unrevoke",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let businessCardFromDatabase = try await application.getSharedBusinessCard(businessCardId: businessCard.requireID())
            #expect(businessCardFromDatabase.first?.revokedAt == nil, "Shared business card should be unrevoked.")
        }
        
        @Test("Shared business card should not be reveoked for other user business card")
        func sharedBusinessCardShoudNotBeRevokedForOtherUserBusinessCard() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "mariaferdix")
            let user = try await application.createUser(userName: "annaferdix")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia", revokedAt: Date())
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "mariaferdix", password: "p@ssword"),
                to: "/shared-business-cards/" + (sharedBusinessCard.stringId() ?? "") + "/unrevoke",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }

        @Test("Not found should be returned for wrong shared card id")
        func notFoundShouldbeReturnedForWrongSharedCardId() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "reniaferdix")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            _ = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia", revokedAt: Date())

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "reniaferdix", password: "p@ssword"),
                to: "/shared-business-cards/123/unrevoke",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
        
        @Test("Unauthorized should be returned for unauthorized user")
        func unauthorizedShouldbeReturnedForUnauthorizedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "klaudiaferdix")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia", revokedAt: Date())

            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards/" + (sharedBusinessCard.stringId() ?? "") + "/unrevoke",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
