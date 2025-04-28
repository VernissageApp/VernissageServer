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
    
    @Suite("SharedBusinessCards (PUT /shared-business-cards/:id/third-party)", .serialized, .tags(.sharedBusinessCards))
    struct SharedBusinessCardsUpdateByThirdPartyActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Shared business card should be returned for correct code")
        func sharedBusinessCardShouldBeReturnedForCorrectCode() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorgawol")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Title #1", thirdPartyName: "Marcin")
            let updateRequest = SharedBusinessCardUpdateRequestDto(thirdPartyName: "Marcin Doe", thirdPartyEmail: "mdoe@example.com", sharedCardUrl: "https://localhost.com")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards/" + sharedBusinessCard.code + "/third-party",
                method: .PUT,
                body: updateRequest
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let sharedBusinessCardFromDatabase = try await application.getSharedBusinessCard(businessCardId: businessCard.requireID())
            #expect(sharedBusinessCardFromDatabase.first?.thirdPartyName == "Marcin Doe", "Third party name should be updated.")
            #expect(sharedBusinessCardFromDatabase.first?.thirdPartyEmail == "mdoe@example.com", "Third party name should be updated.")
        }
        
        @Test("Not found should be returned for wrong code")
        func notFoundShouldBeReturnedForWrongId() async throws {
            // Arrange.
            let updateRequest = SharedBusinessCardUpdateRequestDto(thirdPartyName: "Marcin Doe", thirdPartyEmail: "mdoe@example.com", sharedCardUrl: "https://localhost.com")

            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards/512/third-party",
                method: .PUT,
                body: updateRequest)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
    }
}
