//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func getSetting() async throws -> [Setting] {
        return try await Setting.query(on: self.db).all()
    }
    
    func getSetting(key: SettingKey) async throws -> Setting {
        guard let setting = try await Setting.query(on: self.db).filter(\.$key == key.rawValue).first() else {
            throw SharedApplicationError.unwrap
        }

        return setting
    }
    
    func updateSetting(key: SettingKey, value: SettingValue) async throws {
        let settingFromDatabase = try await self.getSetting(key: key)
        settingFromDatabase.value = value.value()
        try await settingFromDatabase.save(on: self.db)
        
        // After change setting in database we have to refresh application settings cache in the application.
        try await self.initCacheConfiguration()
    }
}
