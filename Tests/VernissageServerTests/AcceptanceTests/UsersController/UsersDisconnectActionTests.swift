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
    
    @Suite("Users (POST /users/:username/disconnect/:role)", .serialized, .tags(.users))
    struct UsersDisconnectActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User should be disconnected with role for super user")
        func userShouldBeDisconnectedWithRoleForSuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nickviolet")
            try await application.attach(user: user, role: Role.administrator)
            let role = try await application.createRole(code: "accountant")
            try await user.$roles.attach(role, on: application.db)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "nickviolet", password: "p@ssword"),
                to: "/users/@\(user.userName)/disconnect/accountant",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try await User.query(on: application.db).filter(\.$userName == "nickviolet").with(\.$roles).first()
            #expect(!userFromDb!.roles.contains { $0.id == role.id! }, "Role should not be attached to the user")
        }
        
        @Test("Nothing should happaned when user tries disconnect not connected role")
        func nothingShouldHappanedWhenUserTriesDisconnectNotConnectedRole() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "alanviolet")
            try await application.attach(user: user, role: Role.administrator)
            let role = try await application.createRole(code: "teacher")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "alanviolet", password: "p@ssword"),
                to: "/users/@\(user.userName)/disconnect/teacher",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try await User.query(on: application.db).filter(\.$userName == "alanviolet").with(\.$roles).first()
            #expect(!userFromDb!.roles.contains { $0.id == role.id! }, "Role should not be attached to the user")
        }
        
        @Test("User should not be disconnected with role if user is not super user")
        func userShouldNotBeDisconnectedWithRoleIfUserIsNotSuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "fennyviolet")
            let role = try await application.createRole(code: "junior-specialist")
            try await user.$roles.attach(role, on: application.db)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "fennyviolet", password: "p@ssword"),
                to: "/users/@\(user.userName)/disconnect/junior-specialist",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Not found status code should be returned if user not exists")
        func notFoundStatusCodeShouldBeReturnedIfUserNotExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "timviolet")
            try await application.attach(user: user, role: Role.administrator)
            let role = try await application.createRole(code: "senior-driver")
            try await user.$roles.attach(role, on: application.db)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "timviolet", password: "p@ssword"),
                to: "/users/@5323/disconnect/senior-driver",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Correct status code should be returned if role not exists")
        func correctStatusCodeShouldBeReturnedIfRoleNotExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "danviolet")
            try await application.attach(user: user, role: Role.administrator)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "danviolet", password: "p@ssword"),
                to: "/users/@\(user.userName)/disconnect/123",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
