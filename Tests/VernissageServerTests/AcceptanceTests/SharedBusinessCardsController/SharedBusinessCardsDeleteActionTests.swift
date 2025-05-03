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
    
    @Suite("SharedBusinessCards (DELTE /shared-business-cards/:id)", .serialized, .tags(.sharedBusinessCards))
    struct SharedBusinessCardsDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Shared business card should be deleted by authorized user.")
        func sharedBusinessCardShouldBeCreatedByAuthorizedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictormionio")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "wictormionio", password: "p@ssword"),
                to: "/shared-business-cards/" + (sharedBusinessCard.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let businessCardFromDatabase = try await application.getSharedBusinessCard(businessCardId: businessCard.requireID())
            #expect(businessCardFromDatabase.count == 0, "Shared business card should be removed.")
        }

        @Test("Not found should be returned for wrong shared card id")
        func notFoundShouldbeReturnedForWrongSharedCardId() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wnorbimionio")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            _ = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia")

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "wnorbimionio", password: "p@ssword"),
                to: "/shared-business-cards/123",
                method: .DELETE)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
        
        @Test("Unauthorized should be returned for unauthorized user")
        func unauthorizedShouldbeReturnedForUnauthorizedUser() async throws {
            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards/111",
                method: .DELETE)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
