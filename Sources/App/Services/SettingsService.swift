//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import JWTKit

extension Application.Services {
    struct SettingsServiceKey: StorageKey {
        typealias Value = SettingsServiceType
    }

    var settingsService: SettingsServiceType {
        get {
            self.application.storage[SettingsServiceKey.self] ?? SettingsService()
        }
        nonmutating set {
            self.application.storage[SettingsServiceKey.self] = newValue
        }
    }
}

protocol SettingsServiceType {
    func get(on application: Application) async throws -> [Setting]
    func get(on request: Request) async throws -> [Setting]
    
    func get(_ key: SettingKey, on request: Request) async throws -> Setting?
    func get(_ key: SettingKey, on application: Application) async throws -> Setting?
    
    func getApplicationSettings(basedOn settingsFromDb: [Setting], application: Application) throws -> ApplicationSettings
}

final class SettingsService: SettingsServiceType {

    func get(on application: Application) async throws -> [Setting] {
        application.logger.info("Downloading application settings from database.")
        return try await Setting.query(on: application.db).all()
    }
    
    func get(on request: Request) async throws -> [Setting] {
        return try await Setting.query(on: request.db).all()
    }
    
    func get(_ key: SettingKey, on request: Request) async throws -> Setting? {
        return try await Setting.query(on: request.db).filter(\.$key == key.rawValue).first()
    }

    func get(_ key: SettingKey, on application: Application) async throws -> Setting? {
        return try await Setting.query(on: application.db).filter(\.$key == key.rawValue).first()
    }
    
    func getApplicationSettings(basedOn settingsFromDb: [Setting], application: Application) throws -> ApplicationSettings {
        guard let privateKey = settingsFromDb.getString(.jwtPrivateKey)?.data(using: .ascii) else {
            throw Abort(.internalServerError, reason: "Private key is not configured in database.")
        }
        
        let rsaKey: RSAKey = try .private(pem: privateKey)
        application.jwt.signers.use(.rs512(key: rsaKey))
        
        let baseAddress = application.settings.getString(for: "vernissage.baseAddress", withDefault: "http://localhost")
        let baseAddressUrl = URL(string: baseAddress)
        
        let publicFolderPath = self.getPublicFolderPath(application: application)
        
        let applicationSettings = ApplicationSettings(
            baseAddress: baseAddress,
            domain: baseAddressUrl?.host ?? "localhost",
            isRecaptchaEnabled: settingsFromDb.getBool(.isRecaptchaEnabled) ?? false,
            isRegistrationOpened: settingsFromDb.getBool(.isRegistrationOpened) ?? false,
            recaptchaKey: settingsFromDb.getString(.recaptchaKey) ?? "",
            eventsToStore: settingsFromDb.getString(.eventsToStore) ?? "",
            publicFolderPath: publicFolderPath
        )
        
        return applicationSettings
    }
    
    private func getPublicFolderPath(application: Application) -> String? {
        guard let localFilesPath = application.settings.getString(for: "vernissage.localFilesPath") else {
            return nil
        }

        if localFilesPath.hasPrefix("/") {
            return localFilesPath
        }
        
        let directoryConfiguration = DirectoryConfiguration.detect()
        return directoryConfiguration.workingDirectory + localFilesPath
    }
}
