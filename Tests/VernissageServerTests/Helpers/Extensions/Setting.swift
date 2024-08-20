//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Setting {
    static func get() async throws -> [Setting] {
        return try await Setting.query(on: SharedApplication.application().db).all()
    }
    
    static func get(key: SettingKey) async throws -> Setting {
        guard let setting = try await Setting.query(on: SharedApplication.application().db).filter(\.$key == key.rawValue).first() else {
            throw SharedApplicationError.unwrap
        }

        return setting
    }
    
    static func update(key: SettingKey, value: SettingValue) async throws {
        let setting = try await self.get(key: key)
        setting.value = value.value()
        
        try await setting.save(on: SharedApplication.application().db)
        
        // After change setting in database we have to refresh application settings cache in the application.
        try await SharedApplication.application().initCacheConfiguration()
    }
}
