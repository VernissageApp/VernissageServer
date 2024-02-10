//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class SettingsUpdateActionTests: CustomTestCase {
    func testCorrectSettingsShouldBeUpdatedBySuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "brucechim")
        try await user.attach(role: Role.administrator)
        let settings = try await Setting.get()
        var settingsDto = SettingsDto(basedOn: settings)
        defer {
            let orginalSettingsDto = SettingsDto(basedOn: settings)
            _ = try? SharedApplication.application().sendRequest(
                as: .user(userName: "brucechim", password: "p@ssword"),
                to: "/settings",
                method: .PUT,
                body: orginalSettingsDto
            )
        }

        settingsDto.isRegistrationOpened = false
        settingsDto.isRegistrationByApprovalOpened = true
        settingsDto.isRegistrationByInvitationsOpened = true
        settingsDto.isRecaptchaEnabled = true
        settingsDto.recaptchaKey = "recaptchaKey"
        settingsDto.corsOrigin = "corsOrigin"
        settingsDto.emailHostname = "emailHostname"
        settingsDto.emailPort = 123
        settingsDto.emailUserName = "emailUserName"
        settingsDto.emailPassword = "emailPassword"
        settingsDto.emailSecureMethod = .startTls
        settingsDto.emailFromAddress = "emailFromAddress"
        settingsDto.emailFromName = "emailFromName"
        settingsDto.eventsToStore = [.accountChangeEmail]
        settingsDto.webTitle = "webTitle"
        settingsDto.webDescription = "webDescription"
        settingsDto.webEmail = "webEmail"
        settingsDto.webThumbnail = "webThumbnail"
        settingsDto.webLanguages = "webLanguages"
        settingsDto.webContactUserId = "webContactUserId"
        
        settingsDto.maxCharacters = 501
        settingsDto.maxMediaAttachments = 5
        settingsDto.imageSizeLimit = 10_485_761
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "brucechim", password: "p@ssword"),
            to: "/settings",
            method: .PUT,
            body: settingsDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let updatedSettings = try await Setting.get()
        let updatedSettingsDto = SettingsDto(basedOn: updatedSettings)

        XCTAssertEqual(updatedSettingsDto.isRegistrationOpened, false, "Setting isRegistrationOpened should be correct.")
        XCTAssertEqual(updatedSettingsDto.isRegistrationByApprovalOpened, true, "Setting isRegistrationByApprovalOpened should be correct.")
        XCTAssertEqual(updatedSettingsDto.isRegistrationByInvitationsOpened, true, "Setting isRegistrationByInvitationsOpened should be correct.")
        XCTAssertEqual(updatedSettingsDto.isRecaptchaEnabled, true, "Setting isRecaptchaEnabled should be correct.")
        XCTAssertEqual(updatedSettingsDto.recaptchaKey, "recaptchaKey", "Setting recaptchaKey should be correct.")
        XCTAssertEqual(updatedSettingsDto.corsOrigin, "corsOrigin", "Setting corsOrigin should be correct.")
        XCTAssertEqual(updatedSettingsDto.emailHostname, "emailHostname", "Setting emailHostname should be correct.")
        XCTAssertEqual(updatedSettingsDto.emailPort, 123, "Setting emailPort should be correct.")
        XCTAssertEqual(updatedSettingsDto.emailUserName, "emailUserName", "Setting emailUserName should be correct.")
        XCTAssertEqual(updatedSettingsDto.emailPassword, "emailPassword", "Setting emailPassword should be correct.")
        XCTAssertEqual(updatedSettingsDto.emailSecureMethod, .startTls, "Setting emailSecureMethod should be correct.")
        XCTAssertEqual(updatedSettingsDto.emailFromAddress, "emailFromAddress", "Setting emailFromAddress should be correct.")
        XCTAssertEqual(updatedSettingsDto.emailFromName, "emailFromName", "Setting emailFromName should be correct.")
        XCTAssertEqual(updatedSettingsDto.eventsToStore, [.accountChangeEmail], "Setting eventsToStore should be correct.")
        XCTAssertEqual(updatedSettingsDto.webTitle, "webTitle", "Setting webTitle should be correct.")
        XCTAssertEqual(updatedSettingsDto.webDescription, "webDescription", "Setting webDescription should be correct.")
        XCTAssertEqual(updatedSettingsDto.webEmail, "webEmail", "Setting webEmail should be correct.")
        XCTAssertEqual(updatedSettingsDto.webThumbnail, "webThumbnail", "Setting webThumbnail should be correct.")
        XCTAssertEqual(updatedSettingsDto.webLanguages, "webLanguages", "Setting webLanguages should be correct.")
        XCTAssertEqual(updatedSettingsDto.webContactUserId, "webContactUserId", "Setting webContactUserId should be correct.")
        XCTAssertEqual(updatedSettingsDto.maxCharacters, 501, "Setting maxCharacters should be correct.")
        XCTAssertEqual(updatedSettingsDto.maxMediaAttachments, 5, "Setting maxMediaAttachments should be correct.")
        XCTAssertEqual(updatedSettingsDto.imageSizeLimit, 10_485_761, "Setting imageSizeLimit should be correct.")
    }

    func testSettingShouldNotBeUpdatedIfUserIsNotSuperUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "georgechim")
        let settings = try await Setting.get()
        let settingsDto = SettingsDto(basedOn: settings)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "georgechim", password: "p@ssword"),
            to: "/settings",
            method: .PUT,
            body: settingsDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testSettingShouldNotBeUpdatedWhenUserIsNotAuthorized() async throws {
        // Arrange.
        _ = try await User.create(userName: "rickichim")
        let settings = try await Setting.get()
        let settingsDto = SettingsDto(basedOn: settings)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/settings",
            method: .PUT,
            body: settingsDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
