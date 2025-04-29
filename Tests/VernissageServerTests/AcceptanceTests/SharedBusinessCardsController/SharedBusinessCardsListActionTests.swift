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
    
    @Suite("SharedBusinessCards (GET /shared-business-cards)", .serialized, .tags(.sharedBusinessCards))
    struct SharedBusinessCardsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of all shared business cards should be returned for authorized user")
        func listOfSharedBusinessCardsShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorvortex")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            _ = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Title #1", thirdPartyName: "Marcin")
            _ = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Title #2", thirdPartyName: "Anna")
            
            // Act.
            let results = try await application.getResponse(
                as: .user(userName: "wictorvortex", password: "p@ssword"),
                to: "/shared-business-cards",
                method: .GET,
                decodeTo: PaginableResultDto<SharedBusinessCardDto>.self
            )
            
            // Assert.
            #expect(results.data.count > 0, "Shared business cards list should be returned.")
        }
        
        @Test("Unauthorized should be returned for unauthorized user")
        func unauthorizedShouldbeReturnedForUnauthorizedUser() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/shared-business-cards", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
