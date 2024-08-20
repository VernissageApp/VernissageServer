//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class UserAliasesCreateActionTests: CustomTestCase {
    func testUserAliasShouldBeCreatedByAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "laraubionix")
        let userAliasDto = UserAliasDto(alias: "laraubionix@alias.com")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "laraubionix", password: "p@ssword"),
            to: "/user-aliases",
            method: .POST,
            body: userAliasDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.created, "Response http status code should be created (201).")
        let userAlias = try await UserAlias.get(alias: "laraubionix@alias.com")
        XCTAssertEqual(userAlias?.aliasNormalized, "LARAUBIONIX@ALIAS.COM", "Normalized alias shoud be set correctly.")
    }
    
    func testUserAliasShouldNotBeCreatedIfAliasWasNotSpecified() async throws {

        // Arrange.
        _ = try await User.create(userName: "georgeubionix")
        let userAliasDto = UserAliasDto(alias: "")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "georgeubionix", password: "p@ssword"),
            to: "/user-aliases",
            method: .POST,
            data: userAliasDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("alias"), "is empty")
    }

    func testUserAliasShouldNotBeCreatedIfAliasIsTooLong() async throws {

        // Arrange.
        _ = try await User.create(userName: "michaelubionix")
        let userAliasDto = UserAliasDto(alias: String.createRandomString(length: 101))

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "michaelubionix", password: "p@ssword"),
            to: "/user-aliases",
            method: .POST,
            data: userAliasDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("alias"), "is greater than maximum of 100 character(s)")
    }
    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        let userAliasDto = UserAliasDto(alias: "rickiubionix@alias.com")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/user-aliases",
            method: .POST,
            body: userAliasDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
