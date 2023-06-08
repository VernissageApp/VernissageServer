//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import Vapor
import Fluent

extension Setting {
    static func get(key: SettingKey) async throws -> Setting {
        guard let setting = try await Setting.query(on: SharedApplication.application().db).filter(\.$key == key.rawValue).first() else {
            throw SharedApplicationError.unwrap
        }

        return setting
    }
    
    static func update(key: SettingKey, value: SettingsValue) async throws {
        let setting = try await self.get(key: key)
        setting.value = value.value()
        
        try await setting.save(on: SharedApplication.application().db)
        
        // After change setting in database we have to refresh application settings cache in the application.
        try await SharedApplication.application().initCacheConfiguration()
    }
}
