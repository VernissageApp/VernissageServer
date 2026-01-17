//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Home cards (DELETE /home-cards/:id)", .serialized, .tags(.homeCards))
    struct HomeCardsDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Home cards should be deleted by authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laraviola")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalHomeCard = try await application.createHomeCard(title: "D0001", body: "Body D0001", order: 101)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laraviola", password: "p@ssword"),
                to: "/home-cards/" + (orginalHomeCard.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let homeCard = try await application.getHomeCard(title: "D0001")
            #expect(homeCard == nil, "Home card should be deleted.")
        }
        
        @Test
        func `Forbidden should be returned for regular user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogoviola")
            let orginalHomeCard = try await application.createHomeCard(title: "D0002", body: "Body D0002", order: 101)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogoviola", password: "p@ssword"),
                to: "/home-cards/" + (orginalHomeCard.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test
        func `Unauthorize should be returned for not authorized user`() async throws {
            
            // Arrange.
            let orginalHomeCard = try await application.createHomeCard(title: "D0003", body: "Body D0003", order: 101)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/home-cards/" + (orginalHomeCard.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
