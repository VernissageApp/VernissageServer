//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class SettingsUpdateActionTests: CustomTestCase {
    func testCorrectSettingsShouldBeUpdatedBySuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "brucechim")
        try user.attach(role: "administrator")
        let setting = try! Setting.get(key: .corsOrigin)
        let settingToUpdate = SettingDto(id: setting.stringId(), key: setting.key, value: "New value")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "brucechim", password: "p@ssword"),
            to: "/settings/\(setting.stringId() ?? "")",
            method: .PUT,
            body: settingToUpdate
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let updatedSettings = try! Setting.get(key: .corsOrigin)

        XCTAssertEqual(updatedSettings.stringId(), settingToUpdate.id, "Setting id should be correct.")
        XCTAssertEqual(updatedSettings.key, settingToUpdate.key, "Setting key should be correct.")
        XCTAssertEqual(updatedSettings.value, settingToUpdate.value, "Setting value should be correct.")
    }

    func testSettingShouldNotBeUpdatedIfUserIsNotSuperUser() throws {

        // Arrange.
        _ = try User.create(userName: "georgechim")
        let setting = try! Setting.get(key: .corsOrigin)
        let settingToUpdate = SettingDto(id: setting.stringId(), key: setting.key, value: "New value")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "georgechim", password: "p@ssword"),
            to: "/settings/\(setting.stringId() ?? "")",
            method: .PUT,
            body: settingToUpdate
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    func testSettingsShouldNotBeUpdatedIfKeyHasBeenChanged() throws {

        // Arrange.
        let user = try User.create(userName: "samchim")
        try user.attach(role: "administrator")
        let setting = try! Setting.get(key: .corsOrigin)
        let settingToUpdate = SettingDto(id: setting.stringId(), key: "changed-key", value: "New value")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "samchim", password: "p@ssword"),
            to: "/settings/\(setting.stringId() ?? "")",
            method: .PUT,
            data: settingToUpdate
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "settingsKeyCannotBeChanged", "Error code should be equal 'settingsKeyCannotBeChanged'.")
    }
}
