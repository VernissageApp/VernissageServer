//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class SettingsGetActionTests: CustomTestCase {
    func testListOfSettingsShouldBeReturnedForSuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robingrick")
        try await user.attach(role: Role.administrator)

        // Act.
        let settings = try SharedApplication.application().getResponse(
            as: .user(userName: "robingrick", password: "p@ssword"),
            to: "/settings",
            method: .GET,
            decodeTo: SettingsDto.self
        )

        // Assert.
        XCTAssertNotNil(settings, "Settings should be returned.")
    }

    func testListOfSettingsShouldNotBeReturnedForNotSuperUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "wictorgrick")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "wictorgrick", password: "p@ssword"),
            to: "/settings",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testListOfSettingsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/settings", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
