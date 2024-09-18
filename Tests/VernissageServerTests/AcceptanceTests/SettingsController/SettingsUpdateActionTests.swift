//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

@Suite("PUT /", .serialized, .tags(.settings))
struct SettingsUpdateActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Correct settings should be updated by super user")
    func correctSettingsShouldBeUpdatedBySuperUser() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "brucechim")
        try await application.attach(user: user, role: Role.administrator)
        let settings = try await application.getSetting()
        var settingsDto = SettingsDto(basedOn: settings)
        defer {
            let orginalSettingsDto = SettingsDto(basedOn: settings)
            _ = try? application.sendRequest(
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
        let response = try application.sendRequest(
            as: .user(userName: "brucechim", password: "p@ssword"),
            to: "/settings",
            method: .PUT,
            body: settingsDto
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let updatedSettings = try await application.getSetting()
        let updatedSettingsDto = SettingsDto(basedOn: updatedSettings)

        #expect(updatedSettingsDto.isRegistrationOpened == false, "Setting isRegistrationOpened should be correct.")
        #expect(updatedSettingsDto.isRegistrationByApprovalOpened == true, "Setting isRegistrationByApprovalOpened should be correct.")
        #expect(updatedSettingsDto.isRegistrationByInvitationsOpened == true, "Setting isRegistrationByInvitationsOpened should be correct.")
        #expect(updatedSettingsDto.isRecaptchaEnabled == true, "Setting isRecaptchaEnabled should be correct.")
        #expect(updatedSettingsDto.recaptchaKey == "recaptchaKey", "Setting recaptchaKey should be correct.")
        #expect(updatedSettingsDto.corsOrigin == "corsOrigin", "Setting corsOrigin should be correct.")
        #expect(updatedSettingsDto.emailHostname == "emailHostname", "Setting emailHostname should be correct.")
        #expect(updatedSettingsDto.emailPort == 123, "Setting emailPort should be correct.")
        #expect(updatedSettingsDto.emailUserName == "emailUserName", "Setting emailUserName should be correct.")
        #expect(updatedSettingsDto.emailPassword == "emailPassword", "Setting emailPassword should be correct.")
        #expect(updatedSettingsDto.emailSecureMethod == .startTls, "Setting emailSecureMethod should be correct.")
        #expect(updatedSettingsDto.emailFromAddress == "emailFromAddress", "Setting emailFromAddress should be correct.")
        #expect(updatedSettingsDto.emailFromName == "emailFromName", "Setting emailFromName should be correct.")
        #expect(updatedSettingsDto.eventsToStore == [.accountChangeEmail], "Setting eventsToStore should be correct.")
        #expect(updatedSettingsDto.webTitle == "webTitle", "Setting webTitle should be correct.")
        #expect(updatedSettingsDto.webDescription == "webDescription", "Setting webDescription should be correct.")
        #expect(updatedSettingsDto.webEmail == "webEmail", "Setting webEmail should be correct.")
        #expect(updatedSettingsDto.webThumbnail == "webThumbnail", "Setting webThumbnail should be correct.")
        #expect(updatedSettingsDto.webLanguages == "webLanguages", "Setting webLanguages should be correct.")
        #expect(updatedSettingsDto.webContactUserId == "webContactUserId", "Setting webContactUserId should be correct.")
        #expect(updatedSettingsDto.maxCharacters == 501, "Setting maxCharacters should be correct.")
        #expect(updatedSettingsDto.maxMediaAttachments == 5, "Setting maxMediaAttachments should be correct.")
        #expect(updatedSettingsDto.imageSizeLimit == 10_485_761, "Setting imageSizeLimit should be correct.")
    }

    @Test("Setting should not be updated if user is not super user")
    func settingShouldNotBeUpdatedIfUserIsNotSuperUser() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "georgechim")
        let settings = try await application.getSetting()
        let settingsDto = SettingsDto(basedOn: settings)

        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "georgechim", password: "p@ssword"),
            to: "/settings",
            method: .PUT,
            body: settingsDto
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    @Test("Setting should not be updated when user is not authorized")
    func settingShouldNotBeUpdatedWhenUserIsNotAuthorized() async throws {
        // Arrange.
        _ = try await application.createUser(userName: "rickichim")
        let settings = try await application.getSetting()
        let settingsDto = SettingsDto(basedOn: settings)

        // Act.
        let response = try application.sendRequest(
            to: "/settings",
            method: .PUT,
            body: settingsDto
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
