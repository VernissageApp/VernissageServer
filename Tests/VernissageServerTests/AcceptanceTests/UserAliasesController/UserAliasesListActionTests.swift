//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class UserAliasesListActionTests: CustomTestCase {
    func testListOfUserAliasesShouldBeReturnedForAuthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robintebor")
        _ = try await UserAlias.create(userId: user.requireID(),
                                       alias: "robintebor@alias.com",
                                       activityPubProfile: "https://alias.com/users/robintebor")
        
        // Act.
        let userAliases = try SharedApplication.application().getResponse(
            as: .user(userName: "robintebor", password: "p@ssword"),
            to: "/user-aliases",
            method: .GET,
            decodeTo: [UserAliasDto].self
        )

        // Assert.
        XCTAssertNotNil(userAliases, "User's aliases should be returned.")
        XCTAssertTrue(userAliases.count == 1, "Some user's aliases should be returned.")
    }
    
    func testOnlyListOfUserAliasesShouldBeReturnedForAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "annatebor")
        let user2 = try await User.create(userName: "mariatebor")
        _ = try await UserAlias.create(userId: user1.requireID(), alias: "annatebor@alias.com", activityPubProfile: "https://alias.com/users/annatebor")
        _ = try await UserAlias.create(userId: user2.requireID(), alias: "mariatebor@alias.com", activityPubProfile: "https://alias.com/users/mariatebor")
        
        // Act.
        let userAliases = try SharedApplication.application().getResponse(
            as: .user(userName: "annatebor", password: "p@ssword"),
            to: "/user-aliases",
            method: .GET,
            decodeTo: [UserAliasDto].self
        )

        // Assert.
        XCTAssertNotNil(userAliases, "User's aliases should be returned.")
        XCTAssertTrue(userAliases.count == 1, "Some user's aliases should be returned.")
        XCTAssertEqual(userAliases.first?.alias, "annatebor@alias.com", "Correct alias should be returned.")
    }
    
    func testListOfUserAliasesShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/user-aliases", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
