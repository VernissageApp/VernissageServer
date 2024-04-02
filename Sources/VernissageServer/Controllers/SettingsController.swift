//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

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
            .get(use: settings)

        rolesGroup
            .grouped(EventHandlerMiddleware(.settingsList))
            .get("public", use: publicSettings)
        
        rolesGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsAdministratorMiddleware())
            .grouped(EventHandlerMiddleware(.settingsUpdate))
            .put(use: update)
    }
}

/// Controller for managing system settings.
///
/// Controller to manage basic system settings. Here we can define contact
/// person, email box settings, etc.
///
/// > Important: Base controller URL: `/api/v1/settings`.
final class SettingsController {

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
    ///     "isRecaptchaEnabled": false,
    ///     "isRegistrationByApprovalOpened": false,
    ///     "isRegistrationByInvitationsOpened": true,
    ///     "isRegistrationOpened": false,
    ///     "maxCharacters": 500,
    ///     "maxMediaAttachments": 4,
    ///     "maximumNumberOfInvitations": 3,
    ///     "recaptchaKey": "",
    ///     "webContactUserId": "7257953010311411713",
    ///     "webDescription": "Vernissage instance.",
    ///     "webEmail": "info@example.com",
    ///     "webLanguages": "en",
    ///     "webThumbnail": "",
    ///     "webTitle": "Vernissage"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: System settings.
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
    ///     "webSentryDsn": "https://1b0056907f5jf6261eb05d3ebd451c33@o4506755493336736.ingest.sentry.io/4506853429433344"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Public system settings.
    func publicSettings(request: Request) async throws -> PublicSettingsDto {
        let webSentryDsn = Environment.get("SENTRY_DSN_WEB") ?? ""
        
        let settingsFromDatabase = try await Setting.query(on: request.db).all()
        let settings = SettingsDto(basedOn: settingsFromDatabase)
        
        let publicSettingsDto = PublicSettingsDto(webSentryDsn: webSentryDsn,
                                                  maximumNumberOfInvitations: settings.maximumNumberOfInvitations)
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
    ///     "isRecaptchaEnabled": false,
    ///     "isRegistrationByApprovalOpened": false,
    ///     "isRegistrationByInvitationsOpened": true,
    ///     "isRegistrationOpened": false,
    ///     "maxCharacters": 500,
    ///     "maxMediaAttachments": 4,
    ///     "maximumNumberOfInvitations": 3,
    ///     "recaptchaKey": "",
    ///     "webContactUserId": "7257953010311411713",
    ///     "webDescription": "Vernissage instance.",
    ///     "webEmail": "info@example.com",
    ///     "webLanguages": "en",
    ///     "webThumbnail": "",
    ///     "webTitle": "Vernissage"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Updated system settings.
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
            
            if settingsDto.isRecaptchaEnabled != settings.getBool(.isRecaptchaEnabled) {
                try await self.update(.isRecaptchaEnabled,
                                      with: .boolean(settingsDto.isRecaptchaEnabled),
                                      on: request,
                                      transaction: database)
            }
            
            if settingsDto.recaptchaKey != settings.getString(.recaptchaKey) {
                try await self.update(.recaptchaKey,
                                      with: .string(settingsDto.recaptchaKey),
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
    }
    
    private func refreshEmailSettings(on request: Request) async throws {
        let settingsService = request.application.services.settingsService
        
        let hostName = try await settingsService.get(.emailHostname, on: request.db)
        let port = try await settingsService.get(.emailPort, on: request.db)
        let userName = try await settingsService.get(.emailUserName, on: request.db)
        let password = try await settingsService.get(.emailPassword, on: request.db)
        let secureMethod = try await settingsService.get(.emailSecureMethod, on: request.db)
        
        let emailsService = request.application.services.emailsService
        emailsService.setServerSettings(on: request.application,
                                        hostName: hostName,
                                        port: port,
                                        userName: userName,
                                        password: password,
                                        secureMethod: secureMethod)
    }
}
