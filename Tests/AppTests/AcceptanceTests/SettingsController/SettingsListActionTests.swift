//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class SettingsListActionTests: CustomTestCase {
    func testListOfSettingsShouldBeReturnedForSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "robingrick")
        try user.attach(role: "administrator")

        // Act.
        let settings = try SharedApplication.application().getResponse(
            as: .user(userName: "robingrick", password: "p@ssword"),
            to: "/settings",
            method: .GET,
            decodeTo: [SettingDto].self
        )

        // Assert.
        XCTAssert(settings.count > 0, "Settings list was returned.")
    }

    func testListOfSettingsShouldNotBeReturnedForNotSuperUser() throws {

        // Arrange.
        _ = try User.create(userName: "wictorgrick")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "wictorgrick", password: "p@ssword"),
            to: "/settings",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be bad request (400).")
    }
}
