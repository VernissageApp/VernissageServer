//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import JWT

final class GetTwoFactorTokenActionTests: CustomTestCase {
    func testTwoFactorTokenShouldBeGeneratedForAuthorizedUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "markusronfil")

        // Act.
        let twoFactorTokenDto = try SharedApplication.application().getResponse(
            as: .user(userName: "markusronfil", password: "p@ssword"),
            to: "/account/get-2fa-token",
            method: .GET,
            decodeTo: TwoFactorTokenDto.self
        )

        // Assert.
        XCTAssertNotNil(twoFactorTokenDto, "New 2FA token should be generated")
        XCTAssertNotNil(twoFactorTokenDto.key, "Key in 2FA token should be generated")
        XCTAssertNotNil(twoFactorTokenDto.backupCodes, "Backup codes in 2FA token should be generated")
    }
    
    func testTwoFactorTokenShouldNotBeGeneratedForUnauthorizedUser() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/account/get-2fa-token", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
