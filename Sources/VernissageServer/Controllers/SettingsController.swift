//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Ink

extension SettingsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("settings")
    
    func boot(routes: RoutesBuilder) throws {
        let rolesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(SettingsController.uri)
                
        rolesGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsAdministratorMiddleware())
            .grouped(EventHandlerMiddleware(.settingsList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: settings)

        rolesGroup
            .grouped(EventHandlerMiddleware(.settingsList))
            .grouped(CacheControlMiddleware(.public()))
            .get("public", use: publicSettings)
        
        rolesGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsAdministratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.settingsUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .on(.PUT, body: .collect(maxSize: "128kb"), use: update)
    }
}

/// Controller for managing system settings.
///
/// Controller to manage basic system settings. Here we can define contact
/// person, email box settings, etc.
///
/// > Important: Base controller URL: `/api/v1/settings`.
struct SettingsController {

    /// Get all settings.
    ///
    /// An endpoint that returns the system settings used during system operation.
    ///
    /// > Important: Endpoint URL: `/api/v1/settings`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/settings" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "corsOrigin": "",
    ///     "emailFromAddress": "noreply@example.com",
    ///     "emailFromName": "Vernissage",
    ///     "emailHostname": "mail.net",
    ///     "emailPassword": "asdw-wdcaas-dswqs",
    ///     "emailPort": 465,
    ///     "emailSecureMethod": "ssl",
    ///     "emailUserName": "noreply@example.com",
    ///     "eventsToStore": [
    ///         "activityPubRead",
    ///         "activityPubInbox",
    ///         "activityPubOutbox",
    ///         "activityPubFollowing",
    ///         "activityPubFollowers",
    ///         "activityPubLiked",
    ///         "activityPubSharedInbox",
    ///         "activityPubStatus"
    ///     ],
    ///     "imageSizeLimit": 10485760,
    ///     "isQuickCaptchaEnabled": false,
    ///     "isRegistrationByApprovalOpened": false,
    ///     "isRegistrationByInvitationsOpened": true,
    ///     "isRegistrationOpened": false,
    ///     "maxCharacters": 500,
    ///     "maxMediaAttachments": 4,
    ///     "maximumNumberOfInvitations": 3,
    ///     "webContactUserId": "7257953010311411713",
    ///     "webDescription": "Vernissage instance.",
    ///     "webEmail": "info@example.com",
    ///     "webLanguages": "en",
    ///     "webThumbnail": "",
    ///     "webTitle": "Vernissage",
    ///     "systemDefaultUserId": "7257953010311411321",
    ///     "isOpenAIEnabled": false,
    ///     "openAIKey": "assg98svsa87y89as7tvd8",
    ///     "patreonUrl": "",
    ///     "mastodonUrl": ""
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: System settings.
    @Sendable
    func settings(request: Request) async throws -> SettingsDto {
        let settingsFromDatabase = try await Setting.query(on: request.db).all()
        let settings = SettingsDto(basedOn: settingsFromDatabase)
        return settings
    }
    
    /// Get only public system settings.
    ///
    /// An endpoint that returns the system settings which can be combined from database settings,
    /// configuration file, environment variables etc.
    ///
    /// > Important: Endpoint URL: `/api/v1/settings/public`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/settings/public" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "maximumNumberOfInvitations": 2,
    ///     "isOpenAIEnabled": false
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Public system settings.
    @Sendable
    func publicSettings(request: Request) async throws -> PublicSettingsDto {
        let publicSettingsKey = String(describing: PublicSettingsDto.self)

        if let publicSettingsFromCache: PublicSettingsDto = try? await request.cache.get(publicSettingsKey) {
            return publicSettingsFromCache
        }
                
        let settingsFromDatabase = try await Setting.query(on: request.db).all()
        let settings = SettingsDto(basedOn: settingsFromDatabase)
        let webPushVapidPublicKey = settings.isWebPushEnabled ? settings.webPushVapidPublicKey : nil
        
        let applicationSettings = request.application.settings.cached
        let imagesUrl = if let imagesUrl = applicationSettings?.imagesUrl, imagesUrl.isEmpty == false {
            imagesUrl
        } else {
            applicationSettings?.s3Address
        }
        
        let parser = MarkdownParser()
        let privacyPolicyContent = parser.html(from: settings.privacyPolicyContent)
        let termsOfServiceContent = parser.html(from: settings.termsOfServiceContent)
        
        let publicSettingsDto = PublicSettingsDto(maximumNumberOfInvitations: settings.maximumNumberOfInvitations,
                                                  isOpenAIEnabled: settings.isOpenAIEnabled,
                                                  webPushVapidPublicKey: webPushVapidPublicKey,
                                                  imagesUrl: imagesUrl,
                                                  showNews: settings.showNews,
                                                  showNewsForAnonymous: settings.showNewsForAnonymous,
                                                  showSharedBusinessCards: settings.showSharedBusinessCards,
                                                  isQuickCaptchaEnabled: settings.isQuickCaptchaEnabled,
                                                  patreonUrl: settings.patreonUrl,
                                                  mastodonUrl: settings.mastodonUrl,
                                                  totalCost: settings.totalCost,
                                                  usersSupport: settings.usersSupport,
                                                  showLocalTimelineForAnonymous: settings.showLocalTimelineForAnonymous,
                                                  showTrendingForAnonymous: settings.showTrendingForAnonymous,
                                                  showEditorsChoiceForAnonymous: settings.showEditorsChoiceForAnonymous,
                                                  showEditorsUsersChoiceForAnonymous: settings.showEditorsUsersChoiceForAnonymous,
                                                  showHashtagsForAnonymous: settings.showHashtagsForAnonymous,
                                                  showCategoriesForAnonymous: settings.showCategoriesForAnonymous,
                                                  privacyPolicyUpdatedAt: settings.privacyPolicyUpdatedAt,
                                                  privacyPolicyContent: privacyPolicyContent,
                                                  termsOfServiceUpdatedAt: settings.termsOfServiceUpdatedAt,
                                                  termsOfServiceContent: termsOfServiceContent,
                                                  customInlineScript: settings.customInlineScript,
                                                  customInlineStyle: settings.customInlineStyle,
                                                  customFileScript: settings.customFileScript,
                                                  customFileStyle: settings.customFileStyle)
        
        try? await request.cache.set(publicSettingsKey, to: publicSettingsDto, expiresIn: .minutes(10))
        return publicSettingsDto
    }
    
    /// Update settings.
    ///
    /// An endpoint that updatessystem settings used during system operation.
    ///
    /// > Important: Endpoint URL: `/api/v1/settings`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/settings" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "corsOrigin": "",
    ///     "emailFromAddress": "noreply@example.com",
    ///     "emailFromName": "Vernissage",
    ///     "emailHostname": "mail.net",
    ///     "emailPassword": "asdw-wdcaas-dswqs",
    ///     "emailPort": 465,
    ///     "emailSecureMethod": "ssl",
    ///     "emailUserName": "noreply@example.com",
    ///     "eventsToStore": [
    ///         "activityPubRead",
    ///         "activityPubInbox",
    ///         "activityPubOutbox",
    ///         "activityPubFollowing",
    ///         "activityPubFollowers",
    ///         "activityPubLiked",
    ///         "activityPubSharedInbox",
    ///         "activityPubStatus"
    ///     ],
    ///     "imageSizeLimit": 10485760,
    ///     "isQuickCaptchaEnabled": false,
    ///     "isRegistrationByApprovalOpened": false,
    ///     "isRegistrationByInvitationsOpened": true,
    ///     "isRegistrationOpened": false,
    ///     "maxCharacters": 500,
    ///     "maxMediaAttachments": 4,
    ///     "maximumNumberOfInvitations": 3,
    ///     "webContactUserId": "7257953010311411713",
    ///     "webDescription": "Vernissage instance.",
    ///     "webEmail": "info@example.com",
    ///     "webLanguages": "en",
    ///     "webThumbnail": "",
    ///     "webTitle": "Vernissage",
    ///     "systemDefaultUserId": "7257953010311411321",
    ///     "patreonUrl": "",
    ///     "mastodonUrl": "",
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Updated system settings.
    @Sendable
    func update(request: Request) async throws -> SettingsDto {
        let settingsDto = try request.content.decode(SettingsDto.self)
        let settings = try await Setting.query(on: request.db).all()
        
        try await request.db.transaction { database in
            // Helper closures to reduce repetition
            let updateBool: (SettingKey, Bool) async throws -> Void = { key, newValue in
                if newValue != settings.getBool(key) {
                    try await self.update(key, with: .boolean(newValue), on: request, transaction: database)
                }
            }
            let updateInt: (SettingKey, Int) async throws -> Void = { key, newValue in
                if newValue != settings.getInt(key) {
                    try await self.update(key, with: .int(newValue), on: request, transaction: database)
                }
            }
            let updateString: (SettingKey, String) async throws -> Void = { key, newValue in
                if newValue != settings.getString(key) {
                    try await self.update(key, with: .string(newValue), on: request, transaction: database)
                }
            }
            
            // Booleans.
            try await updateBool(.isRegistrationOpened, settingsDto.isRegistrationOpened)
            try await updateBool(.isRegistrationByApprovalOpened, settingsDto.isRegistrationByApprovalOpened)
            try await updateBool(.isRegistrationByInvitationsOpened, settingsDto.isRegistrationByInvitationsOpened)
            try await updateBool(.isQuickCaptchaEnabled, settingsDto.isQuickCaptchaEnabled)
            try await updateBool(.isOpenAIEnabled, settingsDto.isOpenAIEnabled)
            try await updateBool(.isWebPushEnabled, settingsDto.isWebPushEnabled)
            try await updateBool(.showNews, settingsDto.showNews)
            try await updateBool(.showNewsForAnonymous, settingsDto.showNewsForAnonymous)
            try await updateBool(.showSharedBusinessCards, settingsDto.showSharedBusinessCards)
            try await updateBool(.showLocalTimelineForAnonymous, settingsDto.showLocalTimelineForAnonymous)
            try await updateBool(.showTrendingForAnonymous, settingsDto.showTrendingForAnonymous)
            try await updateBool(.showEditorsChoiceForAnonymous, settingsDto.showEditorsChoiceForAnonymous)
            try await updateBool(.showEditorsUsersChoiceForAnonymous, settingsDto.showEditorsUsersChoiceForAnonymous)
            try await updateBool(.showHashtagsForAnonymous, settingsDto.showHashtagsForAnonymous)
            try await updateBool(.showCategoriesForAnonymous, settingsDto.showCategoriesForAnonymous)
            try await updateBool(.clearAttachmentsJobEnabled, settingsDto.clearAttachmentsJobEnabled)
            try await updateBool(.clearErrorItemsJobEnabled, settingsDto.clearErrorItemsJobEnabled)
            try await updateBool(.clearFailedLoginsJobEnabled, settingsDto.clearFailedLoginsJobEnabled)
            try await updateBool(.clearQuickCaptchasJobEnabled, settingsDto.clearQuickCaptchasJobEnabled)
            try await updateBool(.createArchiveJobEnabled, settingsDto.createArchiveJobEnabled)
            try await updateBool(.deleteArchiveJobEnabled, settingsDto.deleteArchiveJobEnabled)
            try await updateBool(.locationsJobEnabled, settingsDto.locationsJobEnabled)
            try await updateBool(.longPeriodTrendingJobEnabled, settingsDto.longPeriodTrendingJobEnabled)
            try await updateBool(.purgeStatusesJobEnabled, settingsDto.purgeStatusesJobEnabled)
            try await updateBool(.rescheduleActivityPubJobEnabled, settingsDto.rescheduleActivityPubJobEnabled)
            try await updateBool(.shortPeriodTrendingJobEnabled, settingsDto.shortPeriodTrendingJobEnabled)
            
            // Integers.
            try await updateInt(.emailPort, settingsDto.emailPort)
            try await updateInt(.maximumNumberOfInvitations, settingsDto.maximumNumberOfInvitations)
            try await updateInt(.maxCharacters, settingsDto.maxCharacters)
            try await updateInt(.maxMediaAttachments, settingsDto.maxMediaAttachments)
            try await updateInt(.imageSizeLimit, settingsDto.imageSizeLimit)
            try await updateInt(.statusPurgeAfterDays, settingsDto.statusPurgeAfterDays)
            try await updateInt(.totalCost, settingsDto.totalCost)
            try await updateInt(.usersSupport, settingsDto.usersSupport)
            try await updateInt(.imageQuality, settingsDto.imageQuality)
            
            // Strings.
            try await updateString(.corsOrigin, settingsDto.corsOrigin)
            try await updateString(.emailHostname, settingsDto.emailHostname)
            try await updateString(.emailUserName, settingsDto.emailUserName)
            try await updateString(.emailPassword, settingsDto.emailPassword)
            try await updateString(.emailFromAddress, settingsDto.emailFromAddress)
            try await updateString(.emailFromName, settingsDto.emailFromName)
            try await updateString(.webTitle, settingsDto.webTitle)
            try await updateString(.webDescription, settingsDto.webDescription)
            try await updateString(.webLongDescription, settingsDto.webLongDescription)
            try await updateString(.webEmail, settingsDto.webEmail)
            try await updateString(.webThumbnail, settingsDto.webThumbnail)
            try await updateString(.webLanguages, settingsDto.webLanguages)
            try await updateString(.patreonUrl, settingsDto.patreonUrl)
            try await updateString(.mastodonUrl, settingsDto.mastodonUrl)
            try await updateString(.webContactUserId, settingsDto.webContactUserId)
            try await updateString(.systemDefaultUserId, settingsDto.systemDefaultUserId)
            try await updateString(.openAIKey, settingsDto.openAIKey)
            try await updateString(.openAIModel, settingsDto.openAIModel)
            try await updateString(.webPushEndpoint, settingsDto.webPushEndpoint)
            try await updateString(.webPushSecretKey, settingsDto.webPushSecretKey)
            try await updateString(.webPushVapidSubject, settingsDto.webPushVapidSubject)
            try await updateString(.webPushVapidPublicKey, settingsDto.webPushVapidPublicKey)
            try await updateString(.webPushVapidPrivateKey, settingsDto.webPushVapidPrivateKey)
            try await updateString(.privacyPolicyUpdatedAt, settingsDto.privacyPolicyUpdatedAt)
            try await updateString(.privacyPolicyContent, settingsDto.privacyPolicyContent)
            try await updateString(.termsOfServiceUpdatedAt, settingsDto.termsOfServiceUpdatedAt)
            try await updateString(.termsOfServiceContent, settingsDto.termsOfServiceContent)
            try await updateString(.customInlineScript, settingsDto.customInlineScript)
            try await updateString(.customInlineStyle, settingsDto.customInlineStyle)
            try await updateString(.customFileScript, settingsDto.customFileScript)
            try await updateString(.customFileStyle, settingsDto.customFileStyle)
            try await updateString(.imagesUrl, settingsDto.imagesUrl)
            
            // Complex cases.
            try await self.update(.eventsToStore,
                                  with: .string(settingsDto.eventsToStore.map { $0.rawValue }.joined(separator: ",")),
                                  on: request,
                                  transaction: database)
            
            try await self.update(.emailSecureMethod,
                                  with: .string(settingsDto.emailSecureMethod.rawValue),
                                  on: request,
                                  transaction: database)
        }
        
        // Refresh application settings in cache.
        try await self.refreshApplicationSettings(on: request)

        // Refresh email server settings.
        try await self.refreshEmailSettings(on: request)
        
        let settingsFromDatabase = try await Setting.query(on: request.db).all()
        return SettingsDto(basedOn: settingsFromDatabase)
    }
    
    private func update(_ key: SettingKey, with value: SettingValue, on request: Request, transaction database: Database) async throws {
        let settingsService = request.application.services.settingsService
        guard let setting = try await settingsService.get(key, on: database) else {
            return
        }

        setting.value = value.value()
        try await setting.update(on: database)
    }
    
    private func refreshApplicationSettings(on request: Request) async throws {
        let settingsService = request.application.services.settingsService
        let settingsFromDb = try await settingsService.get(on: request.db)
        let applicationSettings = try await settingsService.getApplicationSettings(basedOn: settingsFromDb, application: request.application)

        request.application.settings.set(applicationSettings, for: ApplicationSettings.self)
        
        let instanceCacheKey = String(describing: InstanceDto.self)
        try? await request.cache.delete(instanceCacheKey)
        
        let publicSettingsKey = String(describing: PublicSettingsDto.self)
        try? await request.cache.delete(publicSettingsKey)
    }
    
    private func refreshEmailSettings(on request: Request) async throws {
        let settingsService = request.application.services.settingsService
        
        let hostName = try await settingsService.get(.emailHostname, on: request.db)
        let port = try await settingsService.get(.emailPort, on: request.db)
        let userName = try await settingsService.get(.emailUserName, on: request.db)
        let password = try await settingsService.get(.emailPassword, on: request.db)
        let secureMethod = try await settingsService.get(.emailSecureMethod, on: request.db)
        
        let emailsService = request.application.services.emailsService
        emailsService.setServerSettings(hostName: hostName,
                                        port: port,
                                        userName: userName,
                                        password: password,
                                        secureMethod: secureMethod,
                                        on: request.application)
    }
}

