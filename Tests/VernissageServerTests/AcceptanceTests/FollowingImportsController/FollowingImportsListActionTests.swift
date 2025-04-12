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
    
    @Suite("FollowingImports (GET /following-imports)", .serialized, .tags(.followingImports))
    struct FollowingImportsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Following imports list should be returned for authorized user")
        func followingImportsListShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorroblox")
            _ = try await application.createFollwingImport(userId: user.requireID(), accounts: ["user1@server.test", "user2@server.test"])
            _ = try await application.createFollwingImport(userId: user.requireID(), accounts: ["user3@server.test", "user4@server.test"])
            _ = try await application.createFollwingImport(userId: user.requireID(), accounts: ["user5@server.test", "user6@server.test"])
            
            // Act.
            let followingImports = try await application.getResponse(
                as: .user(userName: "wictorroblox", password: "p@ssword"),
                to: "/following-imports",
                method: .GET,
                decodeTo: PaginableResultDto<FollowingImportDto>.self
            )
            
            // Assert.
            #expect(followingImports.data.count > 0, "Following imports list should be returned.")
            #expect((followingImports.data.first?.followingImportItems.count ?? 0) > 0, "Following import accounts list should be returned.")
        }
        
        @Test("Following imports list should be returned only for current user")
        func followingImportsListShouldBeReturnedOnlyForCurrentUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "annaroblox")
            let user2 = try await application.createUser(userName: "mariaroblox")
            _ = try await application.createFollwingImport(userId: user1.requireID(), accounts: ["user1@server.test", "user2@server.test"])
            _ = try await application.createFollwingImport(userId: user2.requireID(), accounts: ["user3@server.test", "user4@server.test"])
            
            // Act.
            let followingImports = try await application.getResponse(
                as: .user(userName: "annaroblox", password: "p@ssword"),
                to: "/following-imports",
                method: .GET,
                decodeTo: PaginableResultDto<FollowingImportDto>.self
            )
            
            // Assert.
            #expect(followingImports.data.count == 1, "Only current user following imports list should be returned.")
        }
        
        @Test("Unauthorized should be returned for not authorized")
        func unauthorizedShouldbeReturnedForNotAuthorized() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/following-imports", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
