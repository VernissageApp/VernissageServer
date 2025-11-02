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
    
    @Suite("SharedBusinessCards (GET /shared-business-cards/:id/third-party)", .serialized, .tags(.sharedBusinessCards))
    struct SharedBusinessCardsReadByThirdPartyActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Shared business card should be returned for correct code`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorcodex")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Title #1", thirdPartyName: "Marcin")
            
            // Act.
            let result = try await application.getResponse(
                to: "/shared-business-cards/" + sharedBusinessCard.code + "/third-party",
                method: .GET,
                decodeTo: SharedBusinessCardDto.self
            )
            
            // Assert.
            #expect(result.id != nil, "Shared business card should be returned.")
        }
        
        @Test
        func `Revoked shared business card should not be returned for correct code`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "georiicodex")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Title #1", thirdPartyName: "Marcin", revokedAt: Date())
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards/" + sharedBusinessCard.code + "/third-party",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
        
        @Test
        func `Shared business card should be returned without sensitive information`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "moikacodex")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Title #1", thirdPartyName: "Marcin")
            
            // Act.
            let result = try await application.getResponse(
                to: "/shared-business-cards/" + sharedBusinessCard.code + "/third-party",
                method: .GET,
                decodeTo: SharedBusinessCardDto.self
            )
            
            // Assert.
            #expect(result.title == "", "Title should be cleared.")
            #expect(result.note == "", "Note should be cleared.")
        }

        @Test
        func `Not found should be returned for wrong code`() async throws {
            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards/512/third-party",
                method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
    }
}
