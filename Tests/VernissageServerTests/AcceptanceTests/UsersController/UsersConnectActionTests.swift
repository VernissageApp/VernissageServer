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

extension UsersControllerTests {
    
    @Suite("POST /:username/connect/:role", .serialized, .tags(.users))
    struct UsersConnectActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("User should be connected to role for super user")
        func userShouldBeConnectedToRoleForSuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nickford")
            try await application.attach(user: user, role: Role.administrator)
            let role = try await application.createRole(code: "consultant")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "nickford", password: "p@ssword"),
                to: "/users/\(user.userName)/connect/consultant",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try await User.query(on: application.db).filter(\.$userName == "nickford").with(\.$roles).first()
            #expect(userFromDb!.roles.contains { $0.id == role.id! }, "Role should be attached to the user")
        }
        
        @Test("Nothing should happend when user tries to connect already connected role")
        func nothingShouldHappendWhenUserTriesToConnectAlreadyConnectedRole() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "alanford")
            try await application.attach(user: user, role: Role.administrator)
            let role = try await application.createRole(code: "policeman")
            try await user.$roles.attach(role, on: application.db)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "alanford", password: "p@ssword"),
                to: "/users/\(user.userName)/connect/policeman",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try await User.query(on: application.db).filter(\.$userName == "alanford").with(\.$roles).first()
            #expect(userFromDb!.roles.contains { $0.id == role.id! }, "Role should be attached to the user")
        }
        
        @Test("User should not be connected to role if user is not super user")
        func userShouldNotBeConnectedToRoleIfUserIsNotSuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "wandaford")
            _ = try await application.createRole(code: "senior-consultant")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "wandaford", password: "p@ssword"),
                to: "/users/\(user.userName)/connect/senior-consultant",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Not found stats code should be returned if user not exists")
        func notFoundStatsCodeShouldBeReturnedIfUserNotExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "henryford")
            try await application.attach(user: user, role: Role.administrator)
            _ = try await application.createRole(code: "junior-consultant")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "henryford", password: "p@ssword"),
                to: "/users/123322/connect/junior-consultant",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Correct status code should be returned if role not exists")
        func correctStatusCodeShouldBeReturnedIfRoleNotExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "erikford")
            try await application.attach(user: user, role: Role.administrator)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "erikford", password: "p@ssword"),
                to: "/users/\(user.userName)/connect/123",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
