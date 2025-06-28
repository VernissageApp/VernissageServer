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
        
        let appplicationSettings = request.application.settings.cached
        let imagesUrl = if let imagesUrl = appplicationSettings?.imagesUrl, imagesUrl.isEmpty == false {
            imagesUrl
        } else {
            appplicationSettings?.s3Address
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
            
            
            
            if settingsDto.isRegistrationOpened != settings.getBool(.isRegistrationOpened) {
                try await self.update(.isRegistrationOpened,
                                      with: .boolean(settingsDto.isRegistrationOpened),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.isRegistrationByApprovalOpened != settings.getBool(.isRegistrationByApprovalOpened) {
                try await self.update(.isRegistrationByApprovalOpened,
                                      with: .boolean(settingsDto.isRegistrationByApprovalOpened),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.isRegistrationByInvitationsOpened != settings.getBool(.isRegistrationByInvitationsOpened) {
                try await self.update(.isRegistrationByInvitationsOpened,
                                      with: .boolean(settingsDto.isRegistrationByInvitationsOpened),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.isQuickCaptchaEnabled != settings.getBool(.isQuickCaptchaEnabled) {
                try await self.update(.isQuickCaptchaEnabled,
                                      with: .boolean(settingsDto.isQuickCaptchaEnabled),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.corsOrigin != settings.getString(.corsOrigin) {
                try await self.update(.corsOrigin,
                                      with: .string(settingsDto.corsOrigin),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.emailHostname != settings.getString(.emailHostname) {
                try await self.update(.emailHostname,
                                      with: .string(settingsDto.emailHostname),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.emailPort != settings.getInt(.emailPort) {
                try await self.update(.emailPort,
                                      with: .int(settingsDto.emailPort),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.emailUserName != settings.getString(.emailUserName) {
                try await self.update(.emailUserName,
                                      with: .string(settingsDto.emailUserName),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.emailPassword != settings.getString(.emailPassword) {
                try await self.update(.emailPassword,
                                      with: .string(settingsDto.emailPassword),
                                      on: request,
                                      transaction: database)
            }
                        
            if settingsDto.emailFromAddress != settings.getString(.emailFromAddress) {
                try await self.update(.emailFromAddress,
                                      with: .string(settingsDto.emailFromAddress),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.emailFromName != settings.getString(.emailFromName) {
                try await self.update(.emailFromName,
                                      with: .string(settingsDto.emailFromName),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webTitle != settings.getString(.webTitle) {
                try await self.update(.webTitle,
                                      with: .string(settingsDto.webTitle),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webDescription != settings.getString(.webDescription) {
                try await self.update(.webDescription,
                                      with: .string(settingsDto.webDescription),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webLongDescription != settings.getString(.webLongDescription) {
                try await self.update(.webLongDescription,
                                      with: .string(settingsDto.webLongDescription),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webEmail != settings.getString(.webEmail) {
                try await self.update(.webEmail,
                                      with: .string(settingsDto.webEmail),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webThumbnail != settings.getString(.webThumbnail) {
                try await self.update(.webThumbnail,
                                      with: .string(settingsDto.webThumbnail),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webLanguages != settings.getString(.webLanguages) {
                try await self.update(.webLanguages,
                                      with: .string(settingsDto.webLanguages),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.patreonUrl != settings.getString(.patreonUrl) {
                try await self.update(.patreonUrl,
                                      with: .string(settingsDto.patreonUrl),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.mastodonUrl != settings.getString(.mastodonUrl) {
                try await self.update(.mastodonUrl,
                                      with: .string(settingsDto.mastodonUrl),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.statusPurgeAfterDays != settings.getInt(.statusPurgeAfterDays) {
                try await self.update(.statusPurgeAfterDays,
                                      with: .int(settingsDto.statusPurgeAfterDays),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webContactUserId != settings.getString(.webContactUserId) {
                try await self.update(.webContactUserId,
                                      with: .string(settingsDto.webContactUserId),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.maximumNumberOfInvitations != settings.getInt(.maximumNumberOfInvitations) {
                try await self.update(.maximumNumberOfInvitations,
                                      with: .int(settingsDto.maximumNumberOfInvitations),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.maxCharacters != settings.getInt(.maxCharacters) {
                try await self.update(.maxCharacters,
                                      with: .int(settingsDto.maxCharacters),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.maxMediaAttachments != settings.getInt(.maxMediaAttachments) {
                try await self.update(.maxMediaAttachments,
                                      with: .int(settingsDto.maxMediaAttachments),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.imageSizeLimit != settings.getInt(.imageSizeLimit) {
                try await self.update(.imageSizeLimit,
                                      with: .int(settingsDto.imageSizeLimit),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.systemDefaultUserId != settings.getString(.systemDefaultUserId) {
                try await self.update(.systemDefaultUserId,
                                      with: .string(settingsDto.systemDefaultUserId),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.isOpenAIEnabled != settings.getBool(.isOpenAIEnabled) {
                try await self.update(.isOpenAIEnabled,
                                      with: .boolean(settingsDto.isOpenAIEnabled),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.openAIKey != settings.getString(.openAIKey) {
                try await self.update(.openAIKey,
                                      with: .string(settingsDto.openAIKey),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.openAIModel != settings.getString(.openAIModel) {
                try await self.update(.openAIModel,
                                      with: .string(settingsDto.openAIModel),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.isWebPushEnabled != settings.getBool(.isWebPushEnabled) {
                try await self.update(.isWebPushEnabled,
                                      with: .boolean(settingsDto.isWebPushEnabled),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webPushEndpoint != settings.getString(.webPushEndpoint) {
                try await self.update(.webPushEndpoint,
                                      with: .string(settingsDto.webPushEndpoint),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webPushSecretKey != settings.getString(.webPushSecretKey) {
                try await self.update(.webPushSecretKey,
                                      with: .string(settingsDto.webPushSecretKey),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webPushVapidSubject != settings.getString(.webPushVapidSubject) {
                try await self.update(.webPushVapidSubject,
                                      with: .string(settingsDto.webPushVapidSubject),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webPushVapidPublicKey != settings.getString(.webPushVapidPublicKey) {
                try await self.update(.webPushVapidPublicKey,
                                      with: .string(settingsDto.webPushVapidPublicKey),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.webPushVapidPrivateKey != settings.getString(.webPushVapidPrivateKey) {
                try await self.update(.webPushVapidPrivateKey,
                                      with: .string(settingsDto.webPushVapidPrivateKey),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.totalCost != settings.getInt(.totalCost) {
                try await self.update(.totalCost,
                                      with: .int(settingsDto.totalCost),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.usersSupport != settings.getInt(.usersSupport) {
                try await self.update(.usersSupport,
                                      with: .int(settingsDto.usersSupport),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.showLocalTimelineForAnonymous != settings.getBool(.showLocalTimelineForAnonymous) {
                try await self.update(.showLocalTimelineForAnonymous,
                                      with: .boolean(settingsDto.showLocalTimelineForAnonymous),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.showTrendingForAnonymous != settings.getBool(.showTrendingForAnonymous) {
                try await self.update(.showTrendingForAnonymous,
                                      with: .boolean(settingsDto.showTrendingForAnonymous),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.showEditorsChoiceForAnonymous != settings.getBool(.showEditorsChoiceForAnonymous) {
                try await self.update(.showEditorsChoiceForAnonymous,
                                      with: .boolean(settingsDto.showEditorsChoiceForAnonymous),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.showEditorsUsersChoiceForAnonymous != settings.getBool(.showEditorsUsersChoiceForAnonymous) {
                try await self.update(.showEditorsUsersChoiceForAnonymous,
                                      with: .boolean(settingsDto.showEditorsUsersChoiceForAnonymous),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.showHashtagsForAnonymous != settings.getBool(.showHashtagsForAnonymous) {
                try await self.update(.showHashtagsForAnonymous,
                                      with: .boolean(settingsDto.showHashtagsForAnonymous),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.showCategoriesForAnonymous != settings.getBool(.showCategoriesForAnonymous) {
                try await self.update(.showCategoriesForAnonymous,
                                      with: .boolean(settingsDto.showCategoriesForAnonymous),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.privacyPolicyUpdatedAt != settings.getString(.privacyPolicyUpdatedAt) {
                try await self.update(.privacyPolicyUpdatedAt,
                                      with: .string(settingsDto.privacyPolicyUpdatedAt),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.privacyPolicyContent != settings.getString(.privacyPolicyContent) {
                try await self.update(.privacyPolicyContent,
                                      with: .string(settingsDto.privacyPolicyContent),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.termsOfServiceUpdatedAt != settings.getString(.termsOfServiceUpdatedAt) {
                try await self.update(.termsOfServiceUpdatedAt,
                                      with: .string(settingsDto.termsOfServiceUpdatedAt),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.termsOfServiceContent != settings.getString(.termsOfServiceContent) {
                try await self.update(.termsOfServiceContent,
                                      with: .string(settingsDto.termsOfServiceContent),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.customInlineScript != settings.getString(.customInlineScript) {
                try await self.update(.customInlineScript,
                                      with: .string(settingsDto.customInlineScript),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.customInlineStyle != settings.getString(.customInlineStyle) {
                try await self.update(.customInlineStyle,
                                      with: .string(settingsDto.customInlineStyle),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.customFileScript != settings.getString(.customFileScript) {
                try await self.update(.customFileScript,
                                      with: .string(settingsDto.customFileScript),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.customFileStyle != settings.getString(.customFileStyle) {
                try await self.update(.customFileStyle,
                                      with: .string(settingsDto.customFileStyle),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.imagesUrl != settings.getString(.imagesUrl) {
                try await self.update(.imagesUrl,
                                      with: .string(settingsDto.imagesUrl),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.showNews != settings.getBool(.showNews) {
                try await self.update(.showNews,
                                      with: .boolean(settingsDto.showNews),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.showNewsForAnonymous != settings.getBool(.showNewsForAnonymous) {
                try await self.update(.showNewsForAnonymous,
                                      with: .boolean(settingsDto.showNewsForAnonymous),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.showSharedBusinessCards != settings.getBool(.showSharedBusinessCards) {
                try await self.update(.showSharedBusinessCards,
                                      with: .boolean(settingsDto.showSharedBusinessCards),
                                      on: request,
                                      transaction: database)
            }

            if settingsDto.imageQuality != settings.getInt(.imageQuality) {
                try await self.update(.imageQuality,
                                      with: .int(settingsDto.imageQuality),
                                      on: request,
                                      transaction: database)
            }

            try await self.update(.eventsToStore,
                                  with: .string(settingsDto.eventsToStore.map({ $0.rawValue }).joined(separator: ",")),
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
        let applicationSettings = try settingsService.getApplicationSettings(basedOn: settingsFromDb, application: request.application)

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
