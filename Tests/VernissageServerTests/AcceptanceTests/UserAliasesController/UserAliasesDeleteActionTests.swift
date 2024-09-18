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

@Suite("DELETE /:id", .serialized, .tags(.userAliases))
struct UserAliasesDeleteActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("User alias should be deleted by authorized user")
    func userAliasShouldBeDeletedByAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await application.createUser(userName: "laratequio")
        let orginalUserAlias = try await application.createUserAlias(userId: user.requireID(),
                                                                     alias: "laratequio@alias.com",
                                                                     activityPubProfile: "https://alias.com/users/laratequio")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "laratequio", password: "p@ssword"),
            to: "/user-aliases/" + (orginalUserAlias.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
        let userAlias = try await application.getUserAlias(alias: "laratequio@alias.com")
        #expect(userAlias == nil, "User alias should be deleted.")
    }
    
    @Test("Not found should be returned when deleting other user alias")
    func notFoundShouldBeReturneddWhenDeletingOtherUserAlias() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "moniqtequio")
        let user2 = try await application.createUser(userName: "veronatequio")
        let orginalUserAlias2 = try await application.createUserAlias(userId: user2.requireID(),
                                                                      alias: "veronatequio@alias.com",
                                                                      activityPubProfile: "https://alias.com/users/veronatequio")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "moniqtequio", password: "p@ssword"),
            to: "/user-aliases/" + (orginalUserAlias2.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    @Test("Unauthorize should be returned for not authorized user")
    func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await application.createUser(userName: "christequio")
        let orginalUserAlias = try await application.createUserAlias(userId: user.requireID(),
                                                                     alias: "christequio@alias.com",
                                                                     activityPubProfile: "https://alias.com/users/christequio")
        
        // Act.
        let response = try application.sendRequest(
            to: "/user-aliases/" + (orginalUserAlias.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
