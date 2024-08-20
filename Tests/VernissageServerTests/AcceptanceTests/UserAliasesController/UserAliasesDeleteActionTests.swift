//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class UserAliasesDeleteActionTests: CustomTestCase {
    func testUserAliasShouldBeDeletedByAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "laratequio")
        let orginalUserAlias = try await UserAlias.create(userId: user.requireID(),
                                                          alias: "laratequio@alias.com",
                                                          activityPubProfile: "https://alias.com/users/laratequio")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "laratequio", password: "p@ssword"),
            to: "/user-aliases/" + (orginalUserAlias.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be created (200).")
        let userAlias = try await UserAlias.get(alias: "laratequio@alias.com")
        XCTAssertNil(userAlias, "User alias should be deleted.")
    }
    
    func testNotFoundShouldBeReturneddWhenDeletingOtherUserAlias() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "moniqtequio")
        let user2 = try await User.create(userName: "veronatequio")
        let orginalUserAlias2 = try await UserAlias.create(userId: user2.requireID(),
                                                           alias: "veronatequio@alias.com",
                                                           activityPubProfile: "https://alias.com/users/veronatequio")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "moniqtequio", password: "p@ssword"),
            to: "/user-aliases/" + (orginalUserAlias2.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "christequio")
        let orginalUserAlias = try await UserAlias.create(userId: user.requireID(),
                                                          alias: "christequio@alias.com",
                                                          activityPubProfile: "https://alias.com/users/christequio")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/user-aliases/" + (orginalUserAlias.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
