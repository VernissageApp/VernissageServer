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
    
    @Suite("Users (GET /users/:username/feature)", .serialized, .tags(.statuses))
    struct UsersFeatureActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `User should be featured for moderator`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "roxyborin")
            let user2 = try await application.createUser(userName: "tobyborin")
            try await application.attach(user: user2, role: Role.moderator)
                        
            // Act.
            let userDto = try await application.getResponse(
                as: .user(userName: "tobyborin", password: "p@ssword"),
                to: "/users/@\(user1.userName)/feature",
                method: .POST,
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(userDto.id != nil, "User wasn't returned.")
            #expect(userDto.featured == true, "User should be marked as featured.")
        }
        
        @Test
        func `User should be featured only once`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "nicoleborin")
            let user2 = try await application.createUser(userName: "vikiborin")
            let user3 = try await application.createUser(userName: "franborin")
            try await application.attach(user: user1, role: Role.moderator)
            try await application.attach(user: user2, role: Role.moderator)
            _ = try await application.createFeaturedUser(user: user1, featuredUser: user3)
            
            // Act.
            _ = try await application.getResponse(
                as: .user(userName: "vikiborin", password: "p@ssword"),
                to: "/users/@\(user3.userName)/feature",
                method: .POST,
                decodeTo: UserDto.self
            )
            
            // Assert.
            let allFeaturedUsers = try await application.getAllFeaturedUsers()
            #expect(allFeaturedUsers.count { $0.featuredUser.id == user3.id } == 1, "User wasn't featured once.")
        }
        
        @Test
        func `User should be mark as featured even if other moderator featured user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "zibiborin")
            let user2 = try await application.createUser(userName: "zackborin")
            let user3 = try await application.createUser(userName: "zomoborin")
            try await application.attach(user: user1, role: Role.moderator)
            try await application.attach(user: user2, role: Role.moderator)
            _ = try await application.createFeaturedUser(user: user1, featuredUser: user3)
            
            // Act.
            let userDto = try await application.getResponse(
                as: .user(userName: "zackborin", password: "p@ssword"),
                to: "/users/@\(user3.userName)",
                method: .GET,
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(userDto.id != nil, "User wasn't returned.")
            #expect(userDto.featured == true, "User should be marked as featured.")
        }
        
        @Test
        func `Forbidden should be returned for regular user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carineborin")
            _ = try await application.createUser(userName: "adameborin")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "adameborin", password: "p@ssword"),
                to: "/users/@\(user1.userName)/feature",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test
        func `Not found should be returned if user not exists`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "maxeborin")
            try await application.attach(user: user1, role: Role.moderator)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxeborin", password: "p@ssword"),
                to: "/users/@notfounded/feature",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiqueeborin")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/users/@\(user1.userName)/feature",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
