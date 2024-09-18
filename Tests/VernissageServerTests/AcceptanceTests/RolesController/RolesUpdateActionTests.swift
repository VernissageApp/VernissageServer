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

@Suite("PUT /roles/:id", .serialized, .tags(.roles))
struct RolesUpdateActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Correct role should be updated by super user")
    func correctRoleShouldBeUpdatedBySuperUser() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "brucelee")
        try await application.attach(user: user, role: Role.administrator)
        let role = try await application.createRole(code: "seller")
        let roleToUpdate = RoleDto(id: role.stringId(), code: "seller", title: "Junior serller", description: "Junior seller")

        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "brucelee", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .PUT,
            body: roleToUpdate
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")

        let updatedRole = try #require(await application.getRole(id: role.requireID()))

        #expect(updatedRole.stringId() == roleToUpdate.id, "Role id should be correct.")
        #expect(updatedRole.title == roleToUpdate.title, "Role name should be correct.")
        #expect(updatedRole.description == roleToUpdate.description, "Role description should be correct.")
        #expect(updatedRole.isDefault == roleToUpdate.isDefault, "Role default should be correct.")
        #expect(updatedRole.code == roleToUpdate.code, "Role code should be correct.")
    }

    @Test("Role should not be updated if user is not super user")
    func roleShouldNotBeUpdatedIfUserIsNotSuperUser() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "georgelee")
        let role = try await application.createRole(code: "senior-seller")
        let roleToUpdate = RoleDto(id: role.stringId(), code: "junior-seller", title: "Junior serller", description: "Junior seller")

        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "georgelee", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .PUT,
            body: roleToUpdate
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    @Test("Role should not be updated if code is too long")
    func roleShouldNotBeUpdatedIfCodeIsTooLong() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "wandalee")
        try await application.attach(user: user, role: Role.administrator)
        let role = try await application.createRole(code: "manager1")
        let roleToUpdate = RoleDto(id: role.stringId(), code: "123456789012345678901", title: "Senior manager", description: "Senior manager")

        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "wandalee", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .PUT,
            data: roleToUpdate
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("code") == "is greater than maximum of 20 character(s)")
    }

    @Test("Role should not be updated if name is too long")
    func roleShouldNotBeUpdatedIfNameIsTooLong() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "monikalee")
        try await application.attach(user: user, role: Role.administrator)
        let role = try await application.createRole(code: "manager2")
        let roleToUpdate = RoleDto(id: role.stringId(),
                                   code: "senior-manager",
                                   title: "123456789012345678901234567890123456789012345678901",
                                   description: "Senior manager",
                                   isDefault: true)

        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "monikalee", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .PUT,
            data: roleToUpdate
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("title") == "is greater than maximum of 50 character(s)")
    }

    @Test("Role should not be updated if description is too long")
    func roleShouldNotBeUpdatedIfDescriptionIsTooLong() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "annalee")
        try await application.attach(user: user, role: Role.administrator)
        let role = try await application.createRole(code: "manager3")
        let roleToUpdate = RoleDto(id: role.stringId(),
                                   code: "senior-manager",
                                   title: "Senior manager",
                                   description: "12345678901234567890123456789012345678901234567890" +
                                                "12345678901234567890123456789012345678901234567890" +
                                                "12345678901234567890123456789012345678901234567890" +
                                                "123456789012345678901234567890123456789012345678901",
                                   isDefault: true)

        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "annalee", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .PUT,
            data: roleToUpdate
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("description") == "is greater than maximum of 200 character(s) and is not null")
    }
}

