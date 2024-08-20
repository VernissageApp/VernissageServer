//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import JWT

final class DisableTwoFactorAuthenticationActionTests: CustomTestCase {
    func testTwoFactorTokenShouldBeDisabledForAuthorizedUserWithCorrectToken() async throws {

        // Arrange.
        _ = try await User.create(userName: "markusbiolik")
        let twoFactorTokenDto = try SharedApplication.application().getResponse(
            as: .user(userName: "markusbiolik", password: "p@ssword"),
            to: "/account/get-2fa-token",
            method: .GET,
            decodeTo: TwoFactorTokenDto.self
        )
        
        let twoFactorTokensService = TwoFactorTokensService()
        let tokens = try twoFactorTokensService.generateTokens(key: twoFactorTokenDto.key)

        _ = try SharedApplication.application().sendRequest(
            as: .user(userName: "markusbiolik", password: "p@ssword"),
            to: "/account/enable-2fa",
            method: .POST,
            headers: [ Constants.twoFactorTokenHeader: tokens.first ?? ""]
        )
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "markusbiolik", password: "p@ssword", token: tokens.first),
            to: "/account/disable-2fa",
            method: .POST,
            headers: [ Constants.twoFactorTokenHeader: tokens.last ?? ""]
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }
        
    func testTwoFactorTokenShouldNotBeDisabledForAuthorizedUserWithIncorrectToken() async throws {

        // Arrange.
        _ = try await User.create(userName: "ronaldbiolik")
        let twoFactorTokenDto = try SharedApplication.application().getResponse(
            as: .user(userName: "ronaldbiolik", password: "p@ssword"),
            to: "/account/get-2fa-token",
            method: .GET,
            decodeTo: TwoFactorTokenDto.self
        )
        
        let twoFactorTokensService = TwoFactorTokensService()
        let tokens = try twoFactorTokensService.generateTokens(key: twoFactorTokenDto.key)

        _ = try SharedApplication.application().sendRequest(
            as: .user(userName: "ronaldbiolik", password: "p@ssword"),
            to: "/account/enable-2fa",
            method: .POST,
            headers: [ Constants.twoFactorTokenHeader: tokens.first ?? ""]
        )
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "ronaldbiolik", password: "p@ssword", token: tokens.first),
            to: "/account/disable-2fa",
            method: .POST,
            headers: [ Constants.twoFactorTokenHeader: "444333"]
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testTwoFactorTokenShouldNotBeDisabledForAuthorizedUserWithoutHeader() async throws {

        // Arrange.
        _ = try await User.create(userName: "enyabiolik")
        let twoFactorTokenDto = try SharedApplication.application().getResponse(
            as: .user(userName: "enyabiolik", password: "p@ssword"),
            to: "/account/get-2fa-token",
            method: .GET,
            decodeTo: TwoFactorTokenDto.self
        )
        
        let twoFactorTokensService = TwoFactorTokensService()
        let tokens = try twoFactorTokensService.generateTokens(key: twoFactorTokenDto.key)

        _ = try SharedApplication.application().sendRequest(
            as: .user(userName: "enyabiolik", password: "p@ssword"),
            to: "/account/enable-2fa",
            method: .POST,
            headers: [ Constants.twoFactorTokenHeader: tokens.first ?? ""]
        )
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "enyabiolik", password: "p@ssword", token: tokens.first),
            to: "/account/disable-2fa",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
    }
    
    func testTwoFactorTokenShouldNotBeDisabledForUnauthorizedUser() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/account/disable-2fa",
            method: .POST,
            headers: [ Constants.twoFactorTokenHeader: "12321"]
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
