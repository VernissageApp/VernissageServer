//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class SettingsReadActionTests: XCTestCase {
    func testSettingShouldBeReturnedForSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "robinyrick")
        try user.attach(role: "administrator")
        let setting = try Setting.query(on: SharedApplication.application().db).first().wait()

        // Act.
        let settingDto = try SharedApplication.application().getResponse(
            as: .user(userName: "robinyrick", password: "p@ssword"),
            to: "/settings/\(setting?.id?.uuidString ?? "")",
            method: .GET,
            decodeTo: SettingDto.self
        )

        // Assert.
        XCTAssertEqual(settingDto.id, setting?.id, "Setting id should be correct.")
        XCTAssertEqual(settingDto.key, setting?.key, "Setting key should be correct.")
        XCTAssertEqual(settingDto.value, setting?.value, "Setting value should be correct.")
    }

    func testSettingShouldNotBeReturnedIfUserIsNotSuperUser() throws {

        // Arrange.
        _ = try User.create(userName: "hulkyrick")
        let setting = try Setting.query(on: SharedApplication.application().db).first().wait()

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "hulkyrick", password: "p@ssword"),
            to: "/settings/\(setting?.id?.uuidString ?? "")",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be bad request (400).")
    }

    func testCorrectStatusCodeShouldBeReturnedIfSettingNotExists() throws {

        // Arrange.
        let user = try User.create(userName: "tedyrick")
        try user.attach(role: "administrator")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "tedyrick", password: "p@ssword"),
            to: "/settings/\(UUID().uuidString)",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
