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
    
    @Suite("BusinessCards (GET /business-cards)", .serialized, .tags(.businessCards))
    struct BusinessCardsReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Business card should be returned for authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorbumor")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            
            // Act.
            let result = try await application.getResponse(
                as: .user(userName: "wictorbumor", password: "p@ssword"),
                to: "/business-cards",
                method: .GET,
                decodeTo: BusinessCardDto.self
            )
            
            // Assert.
            #expect(result.id != nil, "Business card should be returned.")
            #expect(result.title == "Title", "Business card title should be returned.")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "martinbumor")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")

            // Act.
            let response = try await application.getErrorResponse(
                to: "/business-cards",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
