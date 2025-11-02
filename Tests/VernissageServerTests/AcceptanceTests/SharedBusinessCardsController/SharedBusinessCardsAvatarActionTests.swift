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
    
    @Suite("SharedBusinessCards (GET /shared-business-cards/:id/avatar)", .serialized, .tags(.sharedBusinessCards))
    struct SharedBusinessCardsAvatarActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Shared business card should be returned for correct code`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorfortuns")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCard = try await application.createSharedBusinessCard(businessCardId: businessCard.requireID(), title: "Title #1", thirdPartyName: "Marcin")
            
            // Act.
            let result = try await application.getResponse(
                to: "/shared-business-cards/" + sharedBusinessCard.code + "/avatar",
                method: .GET,
                decodeTo: BusinessCardAvatarDto.self
            )
            
            // Assert.
            #expect(result.file == "", "File (empty in tests) should be returned.")
            #expect(result.type == "", "Type (empty in tests) should be returned.")
        }
        
        @Test
        func `Not found should be returned for wrong code`() async throws {
            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards/512/avatar",
                method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
    }
}
