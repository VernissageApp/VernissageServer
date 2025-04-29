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
    
    @Suite("SharedBusinessCards (POST /shared-business-cards/:id/message)", .serialized, .tags(.sharedBusinessCards))
    struct SharedBusinessCardsMessageActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Massage to shared business card should be created by authorized user")
        func messageToSharedBusinessCardShouldBeCreatedByAuthoriedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorterbol")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia")
            let message = SharedBusinessCardMessageDto(message: "New message")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "wictorterbol", password: "p@ssword"),
                to: "/shared-business-cards/" + (sharedBusinessCard.stringId() ?? "") + "/message",
                method: .POST,
                body: message
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let businessCardFromDatabase = try await application.getSharedBusinessCard(businessCardId: businessCard.requireID())
            #expect((businessCardFromDatabase.first?.messages.count ?? 0) > 0, "Message should be added to shared business card.")
        }
        
        @Test("Massage to shared business card should not be created to other user business card")
        func messageToSharedBusinessCardShouldNotBeCreatedToOtherUserBusinessCard() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "mariaterbol")
            let user = try await application.createUser(userName: "annaterbol")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia")
            let message = SharedBusinessCardMessageDto(message: "New message")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "mariaterbol", password: "p@ssword"),
                to: "/shared-business-cards/" + (sharedBusinessCard.stringId() ?? "") + "/message",
                method: .POST,
                body: message
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }

        @Test("Not found should be returned for wrong shared card id")
        func notFoundShouldbeReturnedForWrongSharedCardId() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "reniaterbol")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            _ = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia")
            let message = SharedBusinessCardMessageDto(message: "New message")

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "reniaterbol", password: "p@ssword"),
                to: "/shared-business-cards/123/messages",
                method: .POST,
                body: message
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
        
        @Test("Unauthorized should be returned for unauthorized user")
        func unauthorizedShouldbeReturnedForUnauthorizedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "klaudiaterbol")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Place", thirdPartyName: "Monia")
            let message = SharedBusinessCardMessageDto(message: "New message")

            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards/" + (sharedBusinessCard.stringId() ?? "") + "/message",
                method: .POST,
                body: message
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
