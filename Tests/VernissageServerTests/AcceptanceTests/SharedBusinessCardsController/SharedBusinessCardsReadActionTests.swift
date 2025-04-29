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
    
    @Suite("SharedBusinessCards (GET /shared-business-cards/:id)", .serialized, .tags(.sharedBusinessCards))
    struct SharedBusinessCardsReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Shared business card should be returned for authorized user")
        func sharedBusinessCardShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorretopo")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Title #1", thirdPartyName: "Marcin")
            
            // Act.
            let result = try await application.getResponse(
                as: .user(userName: "wictorretopo", password: "p@ssword"),
                to: "/shared-business-cards/" + (sharedBusinessCard.stringId() ?? ""),
                method: .GET,
                decodeTo: SharedBusinessCardDto.self
            )
            
            // Assert.
            #expect(result.id != nil, "Shared business card should be returned.")
        }

        @Test("Not found should be returned for wrong id")
        func notFoundShouldBeReturnedForWrongId() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "gorgiretopo")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "gorgiretopo", password: "p@ssword"),
                to: "/shared-business-cards/512",
                method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
        
        @Test("Unauthorized should be returned for unauthorized user")
        func unauthorizedShouldbeReturnedForUnauthorizedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "marekretopo")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Title #1", thirdPartyName: "Marcin")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards/" + (sharedBusinessCard.stringId() ?? ""),
                method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
