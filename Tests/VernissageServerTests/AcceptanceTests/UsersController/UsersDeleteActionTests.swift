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

@Suite("DELETE /:username", .serialized, .tags(.users))
struct UsersDeleteActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Account should be deleted for authorized user")
    func accountShouldBeDeletedForAuthorizedUser() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "zibibonjek")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "zibibonjek", password: "p@ssword"),
            to: "/users/@zibibonjek",
            method: .DELETE
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "zibibonjek").first()
        #expect(userFromDb == nil, "User should be deleted.")
    }
    
    @Test("Account should be deleted when user is moderator")
    func accountShouldBeDeletedWhenUserIsModerator() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "vorybonjek")
        let user2 = try await application.createUser(userName: "georgebonjek")
        try await application.attach(user: user2, role: Role.moderator)

        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "georgebonjek", password: "p@ssword"),
            to: "/users/@vorybonjek",
            method: .DELETE
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "zibibonjek").first()
        #expect(userFromDb == nil, "User should be deleted.")
    }
    
    @Test("Account should be deleted when user is administrator")
    func accountShouldBeDeletedWhenUserIsAdministrator() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "yorkbonjek")
        let user2 = try await application.createUser(userName: "mikibonjek")
        try await application.attach(user: user2, role: Role.moderator)

        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "mikibonjek", password: "p@ssword"),
            to: "/users/@yorkbonjek",
            method: .DELETE
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "zibibonjek").first()
        #expect(userFromDb == nil, "User should be deleted.")
    }
    
    @Test("Account should be deleted with statuses for authorized user")
    func accountShouldBeDeletedWithStatusesForAuthorizedUser() async throws {
        // Arrange.
        let user1 = try await application.createUser(userName: "ygorbonjek")
        let (_, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note #hastag @ygorbonjek", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "ygorbonjek", password: "p@ssword"),
            to: "/users/@ygorbonjek",
            method: .DELETE
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "ygorbonjek").first()
        #expect(userFromDb == nil, "User should be deleted.")
    }

    @Test("Account should not be deleted if user is not authorized")
    func accountShouldNotBeDeletedIfUserIsNotAuthorized() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "victoriabonjek")

        // Act.
        let response = try application
            .sendRequest(to: "/users/@victoriabonjek", method: .DELETE)

        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }

    @Test("Account should not deleted when user tries to delete not his account")
    func accountShouldNotDeletedWhenUserTriesToDeleteNotHisAccount() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "martabonjek")
        
        _ = try await application.createUser(userName: "kingabonjek",
                                             email: "kingabonjek@testemail.com",
                                             name: "Kinga Bonjek")

        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "martabonjek", password: "p@ssword"),
            to: "/users/@kingabonjek",
            method: .DELETE
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    @Test("Not found should be returned if account not exists")
    func notFoundShouldBeReturnedIfAccountNotExists() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "henrybonjek")

        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "henrybonjek", password: "p@ssword"),
            to: "/users/@notexists",
            method: .DELETE
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should forbidden (403).")
    }
}

