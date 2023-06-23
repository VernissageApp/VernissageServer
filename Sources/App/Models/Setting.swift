//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class Setting: Model {
    static let schema = "Settings"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "key")
    var key: String
    
    @Field(key: "value")
    var value: String

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: Int64? = nil,
         key: String,
         value: String
    ) {
        self.id = id ?? .init(bitPattern: Frostflake.generate())
        self.key = key
        self.value = value
    }
}

/// Allows `Setting` to be encoded to and decoded from HTTP messages.
extension Setting: Content { }

public enum SettingKey: String {
    // General.
    case isRegistrationOpened
    case isRegistrationByApprovalOpened
    case isRegistrationByInvitationsOpened
    case corsOrigin
    
    // Recaptcha.
    case isRecaptchaEnabled
    case recaptchaKey
    
    // Events to store.
    case eventsToStore
    
    // JWT keys for tokens.
    case jwtPrivateKey
    case jwtPublicKey
    
    // Email server.
    case emailHostname
    case emailPort
    case emailUserName
    case emailPassword
    case emailSecureMethod
}

public enum SettingsValue {
    case boolean(Bool)
    case string(String)
    case int(Int)
    
    func value() -> String {
        switch self {
        case .boolean(let bool):
            return bool ? "1" : "0"
        case .string(let string):
            return string
        case .int(let integer):
            return "\(integer)"
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
