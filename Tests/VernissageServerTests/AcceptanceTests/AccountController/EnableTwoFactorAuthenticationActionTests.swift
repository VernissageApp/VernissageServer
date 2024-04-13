//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import JWT

final class EnableTwoFactorAuthenticationActionTests: CustomTestCase {
    func testTwoFactorTokenShouldBeEnabledForAuthorizedUserWithCorrectToken() async throws {

        // Arrange.
        _ = try await User.create(userName: "markustebix")
        let twoFactorTokenDto = try SharedApplication.application().getResponse(
            as: .user(userName: "markustebix", password: "p@ssword"),
            to: "/account/get-2fa-token",
            method: .GET,
            decodeTo: TwoFactorTokenDto.self
        )
        
        let twoFactorTokensService = TwoFactorTokensService()
        let tokens = try twoFactorTokensService.generateTokens(key: twoFactorTokenDto.key)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "markustebix", password: "p@ssword"),
            to: "/account/enable-2fa",
            method: .POST,
            headers: [ Constants.twoFactorTokenHeader: tokens.first ?? ""]
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }
    
    func testTwoFactorTokenShouldBeRequiredDuringLogin() async throws {

        // Arrange.
        _ = try await User.create(userName: "enridtebix")
        let twoFactorTokenDto = try SharedApplication.application().getResponse(
            as: .user(userName: "enridtebix", password: "p@ssword"),
            to: "/account/get-2fa-token",
            method: .GET,
            decodeTo: TwoFactorTokenDto.self
        )
        
        let twoFactorTokensService = TwoFactorTokensService()
        let tokens = try twoFactorTokensService.generateTokens(key: twoFactorTokenDto.key)

        _ = try SharedApplication.application().sendRequest(
            as: .user(userName: "enridtebix", password: "p@ssword"),
            to: "/account/enable-2fa",
            method: .POST,
            headers: [ Constants.twoFactorTokenHeader: tokens.first ?? ""]
        )
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/account/login",
            method: .POST,
            body: LoginRequestDto(userNameOrEmail: "enridtebix", password: "p@ssword"))

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.preconditionRequired, "Response http status code should be preconditionRequired (428).")
    }
    
    func testTwoFactorTokenShouldNotBeEnabledForAuthorizedUserWithIncorrectToken() async throws {

        // Arrange.
        _ = try await User.create(userName: "evatebix")
        _ = try SharedApplication.application().getResponse(
            as: .user(userName: "evatebix", password: "p@ssword"),
            to: "/account/get-2fa-token",
            method: .GET,
            decodeTo: TwoFactorTokenDto.self
        )
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "evatebix", password: "p@ssword"),
            to: "/account/enable-2fa",
            method: .POST,
            headers: [ Constants.twoFactorTokenHeader: "12321"]
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testTwoFactorTokenShouldNotBeEnabledForAuthorizedUserWithoutHeader() async throws {

        // Arrange.
        _ = try await User.create(userName: "ronaldtebix")
        _ = try SharedApplication.application().getResponse(
            as: .user(userName: "ronaldtebix", password: "p@ssword"),
            to: "/account/get-2fa-token",
            method: .GET,
            decodeTo: TwoFactorTokenDto.self
        )
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "ronaldtebix", password: "p@ssword"),
            to: "/account/enable-2fa",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
    }
    
    func testTwoFactorTokenShouldNotBeEnabledForUnauthorizedUser() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/account/enable-2fa",
            method: .POST,
            headers: [ Constants.twoFactorTokenHeader: "12321"]
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
