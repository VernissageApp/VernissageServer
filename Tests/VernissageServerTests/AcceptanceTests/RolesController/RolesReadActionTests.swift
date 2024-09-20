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
    
    @Suite("Roles (GET /roles/:id)", .serialized, .tags(.roles))
    struct RolesReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Role should be returned for super user")
        func roleShouldBeReturnedForSuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinyellow")
            try await application.attach(user: user, role: Role.administrator)
            let role = try await application.createRole(code: "senior-architect")
            
            // Act.
            let roleDto = try application.getResponse(
                as: .user(userName: "robinyellow", password: "p@ssword"),
                to: "/roles/\(role.stringId() ?? "")",
                method: .GET,
                decodeTo: RoleDto.self
            )
            
            // Assert.
            #expect(roleDto.id == role.stringId(), "Role id should be correct.")
            #expect(roleDto.title == role.title, "Role name should be correct.")
            #expect(roleDto.code == role.code, "Role code should be correct.")
            #expect(roleDto.description == role.description, "Role description should be correct.")
            #expect(roleDto.isDefault == role.isDefault, "Role default should be correct.")
        }
        
        @Test("Role should not be returned if user is not super user")
        func roleShouldNotBeReturnedIfUserIsNotSuperUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "hulkyellow")
            let role = try await application.createRole(code: "senior-developer")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "hulkyellow", password: "p@ssword"),
                to: "/roles/\(role.stringId() ?? "")",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be bad request (400).")
        }
        
        @Test("Correct status code should be returned if role not exists")
        func correctStatusCodeShouldBeReturnedIdRoleNotExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "tedyellow")
            try await application.attach(user: user, role: Role.administrator)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "tedyellow", password: "p@ssword"),
                to: "/roles/757392",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
