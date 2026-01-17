//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Home cards (GET /home-cards)", .serialized, .tags(.homeCards))
    struct HomeCardsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Home cards list should be returned for authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorpaniek")
            try await application.attach(user: user, role: Role.moderator)
            _ = try await application.createHomeCard(title: "L0001", body: "Body L0001", order: 101)
            _ = try await application.createHomeCard(title: "L0002", body: "Body L0002", order: 102)
            
            // Act.
            let homeCards = try await application.getResponse(
                as: .user(userName: "wictorpaniek", password: "p@ssword"),
                to: "/home-cards",
                method: .GET,
                decodeTo: PaginableResultDto<HomeCardDto>.self
            )
            
            // Assert.
            #expect(homeCards.data.count > 0, "Home cards list should be returned.")
        }
        
        @Test
        func `Home cards list should not be returned for unauthorized user`() async throws {
            
            // Act.
            let response = try await application.sendRequest(
                to: "/home-cards",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
