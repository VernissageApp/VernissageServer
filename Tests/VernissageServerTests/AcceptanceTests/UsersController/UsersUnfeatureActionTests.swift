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
    
    @Suite("Users (POST /users/:username/unfeature)", .serialized, .tags(.statuses))
    struct UsersUnfeatureActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User should be unfeatured for moderator")
        func userShouldBeUnfeaturedForModerator() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "maximgupok")
            let user2 = try await application.createUser(userName: "roxygupok")
            
            try await application.attach(user: user1, role: Role.moderator)
            _ = try await application.createFeaturedUser(user: user1, featuredUser: user2)
            
            // Act.
            let userDto = try application.getResponse(
                as: .user(userName: "maximgupok", password: "p@ssword"),
                to: "/users/@\(user2.userName)/unfeature",
                method: .POST,
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(userDto.id != nil, "User wasn't unfeatured.")
            #expect(userDto.featured == false, "User should be marked as unfeatured.")
        }
        
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldbeReturnedForRegularUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "caringupok")
            let user2 = try await application.createUser(userName: "adamgupok")
            _ = try await application.createFeaturedUser(user: user1, featuredUser: user2)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "caringupok", password: "p@ssword"),
                to: "/users/@\(user2.userName)/unfeature",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Not found should be returned if user not exists")
        func notFoundShouldBeReturnedIfUserNotExists() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "maxgupok")
            try await application.attach(user: user1, role: Role.moderator)
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "maxgupok", password: "p@ssword"),
                to: "/users/@notfounded/unfeature",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorized should be returned for not authorized user")
        func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiquegupok")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/users/@\(user1.userName)/unfeature",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
