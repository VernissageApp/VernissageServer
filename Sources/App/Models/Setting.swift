//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

final class Setting: Model {
    static let schema = "Settings"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "key")
    var key: String
    
    @Field(key: "value")
    var value: String

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil,
         key: String,
         value: String
    ) {
        self.id = id
        self.key = key
        self.value = value
    }
}

/// Allows `Setting` to be encoded to and decoded from HTTP messages.
extension Setting: Content { }

public enum SettingKey: String {
    case baseAddress
    case domain
    case jwtPrivateKey
    case jwtPublicKey
    case isRecaptchaEnabled
    case isRegistrationOpened
    case recaptchaKey
    case eventsToStore
    case corsOrigin
}

public enum SettingsValue {
    case boolean(Bool)
    case string(String)
    
    func value() -> String {
        switch self {
        case .boolean(let bool):
            return bool ? "1" : "0"
        case .string(let string):
            return string
        }
    }
}

extension Array where Element == Setting {
    func getSetting(_ key: SettingKey) -> Setting? {
        for item in self where item.key == key.rawValue {
            return item
        }
        
        return nil
    }
    
    func getInt(_ key: SettingKey) -> Int? {
        guard let setting = self.getSetting(key) else {
            return nil
        }

        return Int(setting.value)
    }

    func getString(_ key: SettingKey) -> String? {
        return self.getSetting(key)?.value
    }

    func getBool(_ key: SettingKey) -> Bool? {
        guard let setting = self.getSetting(key) else {
            return nil
        }

        return Int(setting.value) ?? 0 == 1
    }
}
