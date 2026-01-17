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
    
    @Suite("Home cards (GET /home-cards/cached)", .serialized, .tags(.homeCards))
    struct HomeCardsCachedListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Home cards list should be returned for authorized user`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "wictorfroks")
            _ = try await application.createHomeCard(title: "L0001", body: "Body L0001", order: 101)
            _ = try await application.createHomeCard(title: "L0002", body: "Body L0002", order: 102)
            
            // Act.
            let homeCards = try await application.getResponse(
                as: .user(userName: "wictorfroks", password: "p@ssword"),
                to: "/home-cards/cached",
                method: .GET,
                decodeTo: PaginableResultDto<HomeCardDto>.self
            )
            
            // Assert.
            #expect(homeCards.data.count > 0, "Home cards list should be returned.")
        }
        
        @Test
        func `Home cards list should be returned for unauthorized user`() async throws {
            // Arrange.
            _ = try await application.createHomeCard(title: "L0003", body: "Body L0003", order: 101)
            _ = try await application.createHomeCard(title: "L0004", body: "Body L0004", order: 102)
            
            // Act.
            let homeCards = try await application.getResponse(
                to: "/home-cards/cached",
                method: .GET,
                decodeTo: PaginableResultDto<HomeCardDto>.self
            )
            
            // Assert.
            #expect(homeCards.data.count > 0, "Home cards list should be returned.")
        }
    }
}
