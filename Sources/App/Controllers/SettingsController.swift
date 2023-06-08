//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Controller for managing system settings.
final class SettingsController: RouteCollection {

    public static let uri: PathComponent = .constant("settings")
    
    func boot(routes: RoutesBuilder) throws {
        let rolesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(SettingsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsSuperUserMiddleware())
                
        rolesGroup
            .grouped(EventHandlerMiddleware(.settingsList))
            .get(use: list)
        
        rolesGroup
            .grouped(EventHandlerMiddleware(.settingsRead))
            .get(":id", use: read)
        
        rolesGroup
            .grouped(EventHandlerMiddleware(.settingsUpdate))
            .put(":id", use: update)
    }

    /// Get all settings.
    func list(request: Request) async throws -> [SettingDto] {
        let settings = try await Setting.query(on: request.db).all()
        return settings.map { setting in SettingDto(from: setting) }
    }

    /// Get specific setting.
    func read(request: Request) async throws -> SettingDto {
        guard let settingId = request.parameters.get("id", as: UUID.self) else {
            throw SettingError.incorrectSettingId
        }

        let setting = try await self.getSettingById(on: request, settingId: settingId)
        guard let setting else {
            throw EntityNotFoundError.settingNotFound
        }
        
        return SettingDto(from: setting)
    }

    /// Update specific setting.
    func update(request: Request) async throws -> SettingDto {
        guard let settingId = request.parameters.get("id", as: UUID.self) else {
            throw SettingError.incorrectSettingId
        }
        
        let settingDto = try request.content.decode(SettingDto.self)
        try SettingDto.validate(content: request)

        let setting = try await self.getSettingById(on: request, settingId: settingId)
        guard let setting else {
            throw EntityNotFoundError.settingNotFound
        }
        
        if settingDto.key != setting.key {
            throw SettingError.settingsKeyCannotBeChanged
        }
        
        // Update setting in database.
        try await self.updateSetting(on: request, from: settingDto, to: setting)
        
        // Refresh application settings in cache.
        try await self.refreshApplicationSettings(on: request)
        
        return SettingDto(from: setting)
    }

    private func getSettingById(on request: Request, settingId: UUID) async throws -> Setting? {
        let setting = try await Setting.find(settingId, on: request.db)
        return setting
    }

    private func updateSetting(on request: Request, from settingDto: SettingDto, to setting: Setting) async throws {
        setting.value = settingDto.value
        try await setting.update(on: request.db)
    }
    
    private func refreshApplicationSettings(on request: Request) async throws {
        let settingsService = request.application.services.settingsService
        let settingsFromDb = try await settingsService.get(on: request)
        let applicationSettings = try settingsService.getApplicationSettings(basedOn: settingsFromDb, application: request.application)

        request.application.settings.set(applicationSettings, for: ApplicationSettings.self)
    }
}
