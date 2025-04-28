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
    
    @Suite("SharedBusinessCards (POST /shared-business-cards/:id/third-party/message)", .serialized, .tags(.sharedBusinessCards))
    struct SharedBusinessCardsMessagesByThirdPartyActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Massage to shared business card should be created for correct code")
        func messageToSharedBusinessCardShouldBeCreatedForCorrectCode() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictoranioma")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia")
            let message = SharedBusinessCardMessageDto(message: "New message")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards/" + sharedBusinessCard.code + "/third-party/message",
                method: .POST,
                body: message
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let businessCardFromDatabase = try await application.getSharedBusinessCard(businessCardId: businessCard.requireID())
            #expect((businessCardFromDatabase.first?.messages.count ?? 0) > 0, "Message should be added to shared business card.")
        }
        
        @Test("Not found should be returned for wrong code")
        func notFoundShouldbeReturnedForWrongCode() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "reniaanioma")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            _ = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia")
            let message = SharedBusinessCardMessageDto(message: "New message")

            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards/123/third-party/message",
                method: .POST,
                body: message
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
    }
}
