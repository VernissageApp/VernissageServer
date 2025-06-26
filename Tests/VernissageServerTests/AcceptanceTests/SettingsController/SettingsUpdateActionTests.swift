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

extension ControllersTests {
    
    @Suite("Settings (PUT /settings)", .serialized, .tags(.settings))
    struct SettingsUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Correct settings should be updated by super user")
        func correctSettingsShouldBeUpdatedBySuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "brucechim")
            try await application.attach(user: user, role: Role.administrator)
            let settings = try await application.getSetting()
            var settingsDto = SettingsDto(basedOn: settings)
            let orginalSettingsDto = SettingsDto(basedOn: settings)
            
            settingsDto.isRegistrationOpened = false
            settingsDto.isRegistrationByApprovalOpened = true
            settingsDto.isRegistrationByInvitationsOpened = true
            settingsDto.isQuickCaptchaEnabled = true
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
            settingsDto.patreonUrl = "patreonUrl"
            settingsDto.mastodonUrl = "mastodonUrl"
            settingsDto.statusPurgeAfterDays = 188
            settingsDto.imagesUrl = "https://images.url"
            settingsDto.imageQuality = 90
            
            settingsDto.showNews = true
            settingsDto.showNewsForAnonymous = true
            settingsDto.showSharedBusinessCards = true
            
            settingsDto.isWebPushEnabled = false
            settingsDto.webPushEndpoint = "webPushEndpoint"
            settingsDto.webPushSecretKey = "webPushSecretKey"
            settingsDto.webPushVapidPublicKey = "webPushVapidPublicKey"
            settingsDto.webPushVapidPrivateKey = "webPushVapidPrivateKey"
            settingsDto.webPushVapidSubject = "webPushVapidSubject"
            
            settingsDto.totalCost = 666
            settingsDto.usersSupport = 111
            
            settingsDto.showLocalTimelineForAnonymous = false
            settingsDto.showTrendingForAnonymous = false
            settingsDto.showEditorsChoiceForAnonymous = false
            settingsDto.showEditorsUsersChoiceForAnonymous = false
            settingsDto.showHashtagsForAnonymous = false
            settingsDto.showCategoriesForAnonymous = false
            
            settingsDto.privacyPolicyUpdatedAt = "privacyPolicyUpdatedAt"
            settingsDto.privacyPolicyContent = Constants.defaultPrivacyPolicy + Constants.defaultPrivacyPolicy
            settingsDto.termsOfServiceUpdatedAt = "termsOfServiceUpdatedAt"
            settingsDto.termsOfServiceContent = Constants.defaultTermsOfService + Constants.defaultTermsOfService
            
            settingsDto.maxCharacters = 501
            settingsDto.maxMediaAttachments = 5
            settingsDto.imageSizeLimit = 10_485_761
            
            settingsDto.customInlineScript = "customInlineScript"
            settingsDto.customInlineStyle = "customInlineStyle"
            settingsDto.customFileScript = "customFileScript"
            settingsDto.customFileStyle = "customFileStyle"
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "brucechim", password: "p@ssword"),
                to: "/settings",
                method: .PUT,
                body: settingsDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let updatedSettings = try await application.getSetting()
            let updatedSettingsDto = SettingsDto(basedOn: updatedSettings)
            
            // Rollback settings.
            _ = try? await application.sendRequest(
                as: .user(userName: "brucechim", password: "p@ssword"),
                to: "/settings",
                method: .PUT,
                body: orginalSettingsDto
            )
            
            #expect(updatedSettingsDto.isRegistrationOpened == false, "Setting isRegistrationOpened should be correct.")
            #expect(updatedSettingsDto.isRegistrationByApprovalOpened == true, "Setting isRegistrationByApprovalOpened should be correct.")
            #expect(updatedSettingsDto.isRegistrationByInvitationsOpened == true, "Setting isRegistrationByInvitationsOpened should be correct.")
            #expect(updatedSettingsDto.isQuickCaptchaEnabled == true, "Setting isQuickCaptchaEnabled should be correct.")
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
            #expect(updatedSettingsDto.patreonUrl == "patreonUrl", "Setting webEmail should be correct.")
            #expect(updatedSettingsDto.mastodonUrl == "mastodonUrl", "Setting webEmail should be correct.")
            #expect(updatedSettingsDto.statusPurgeAfterDays == 188, "Setting statusPurgeAfterDays should be correct.")
            #expect(updatedSettingsDto.imagesUrl == "https://images.url", "Setting imagesUrl should be correct.")
            #expect(updatedSettingsDto.imageQuality == 90, "Setting imageQuality should be correct.")
            
            #expect(updatedSettingsDto.showNews == true, "Setting showNews should be correct.")
            #expect(updatedSettingsDto.showNewsForAnonymous == true, "Setting showNewsForAnonymous should be correct.")
            #expect(updatedSettingsDto.showSharedBusinessCards == true, "Setting showSharedBusinessCards should be correct.")
            
            #expect(updatedSettingsDto.isWebPushEnabled == false, "Setting isWebPushEnabled should be correct.")
            #expect(updatedSettingsDto.webPushEndpoint == "webPushEndpoint", "Setting webPushEndpoint should be correct.")
            #expect(updatedSettingsDto.webPushSecretKey == "webPushSecretKey", "Setting webPushSecretKey should be correct.")
            #expect(updatedSettingsDto.webPushVapidPublicKey == "webPushVapidPublicKey", "Setting webPushVapidPublicKey should be correct.")
            #expect(updatedSettingsDto.webPushVapidPrivateKey == "webPushVapidPrivateKey", "Setting webPushVapidPrivateKey should be correct.")
            #expect(updatedSettingsDto.webPushVapidSubject == "webPushVapidSubject", "Setting webPushVapidSubject should be correct.")
            
            #expect(updatedSettingsDto.totalCost == 666, "Setting totalCost should be correct.")
            #expect(updatedSettingsDto.usersSupport == 111, "Setting usersSupport should be correct.")
            
            #expect(updatedSettingsDto.showLocalTimelineForAnonymous == false, "Setting showLocalTimelineForAnonymous should be correct.")
            #expect(updatedSettingsDto.showTrendingForAnonymous == false, "Setting showTrendingForAnonymous should be correct.")
            #expect(updatedSettingsDto.showEditorsChoiceForAnonymous == false, "Setting showEditorsChoiceForAnonymous should be correct.")
            #expect(updatedSettingsDto.showEditorsUsersChoiceForAnonymous == false, "Setting showEditorsUsersChoiceForAnonymous should be correct.")
            #expect(updatedSettingsDto.showHashtagsForAnonymous == false, "Setting showHashtagsForAnonymous should be correct.")
            #expect(updatedSettingsDto.showCategoriesForAnonymous == false, "Setting showCategoriesForAnonymous should be correct.")
            
            #expect(updatedSettingsDto.privacyPolicyUpdatedAt == "privacyPolicyUpdatedAt", "Setting privacyPolicyUpdatedAt should be correct.")
            #expect(updatedSettingsDto.privacyPolicyContent == settingsDto.privacyPolicyContent, "Setting privacyPolicyContent should be correct.")
            #expect(updatedSettingsDto.termsOfServiceUpdatedAt == "termsOfServiceUpdatedAt", "Setting termsOfServiceUpdatedAt should be correct.")
            #expect(updatedSettingsDto.termsOfServiceContent == settingsDto.termsOfServiceContent, "Setting termsOfServiceContent should be correct.")
            
            #expect(updatedSettingsDto.customInlineScript == settingsDto.customInlineScript, "Setting customInlineScript should be correct.")
            #expect(updatedSettingsDto.customInlineStyle == settingsDto.customInlineStyle, "Setting customInlineStyle should be correct.")
            #expect(updatedSettingsDto.customFileScript == settingsDto.customFileScript, "Setting customFileScript should be correct.")
            #expect(updatedSettingsDto.customFileStyle == settingsDto.customFileStyle, "Setting customFileStyle should be correct.")
        }
        
        @Test("Setting should not be updated if user is not super user")
        func settingShouldNotBeUpdatedIfUserIsNotSuperUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "georgechim")
            let settings = try await application.getSetting()
            let settingsDto = SettingsDto(basedOn: settings)
            
            // Act.
            let response = try await application.sendRequest(
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
            let response = try await application.sendRequest(
                to: "/settings",
                method: .PUT,
                body: settingsDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
