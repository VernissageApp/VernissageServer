//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application {

    func seedDictionaries() throws {
        let database = self.db
        try settings(on: database)
        try roles(on: database)
    }
    
    func seedAdmin() throws {
        let database = self.db
        try users(on: database)
    }

    private func settings(on database: Database) throws {
        let settings = try Setting.query(on: database).all().wait()

        // General.
        try ensureSettingExists(on: database, existing: settings, key: .isRecaptchaEnabled, value: .boolean(false))
        try ensureSettingExists(on: database, existing: settings, key: .recaptchaKey, value: .string(""))
        try ensureSettingExists(on: database, existing: settings, key: .isRegistrationOpened, value: .boolean(true))
        try ensureSettingExists(on: database, existing: settings, key: .corsOrigin, value: .string(""))
        
        // Events.
        try ensureSettingExists(on: database,
                                existing: settings,
                                key: .eventsToStore,
                                value: .string(EventType.allCases.map { item -> String in item.rawValue }.joined(separator: ",")))

        // JWT keys.
        let (privateKey, publicKey) = try CryptoService().generateKeys()
        try ensureSettingExists(on: database, existing: settings, key: .jwtPrivateKey, value: .string(privateKey))
        try ensureSettingExists(on: database, existing: settings, key: .jwtPublicKey, value: .string(publicKey))
    }

    private func roles(on database: Database) throws {
        let roles = try Role.query(on: database).all().wait()

        try ensureRoleExists(on: database,
                             existing: roles,
                             code: "administrator",
                             title: "Administrator",
                             description: "Users have access to whole system.",
                             hasSuperPrivileges: true,
                             isDefault: false)

        try ensureRoleExists(on: database,
                             existing: roles,
                             code: "member",
                             title: "Member",
                             description: "Users have access to public part of system.",
                             hasSuperPrivileges: false,
                             isDefault: true)
    }
    
    private func users(on database: Database) throws {
        try ensureAdminExist(on: database)
    }

    private func ensureSettingExists(on database: Database, existing settings: [Setting], key: SettingKey, value: SettingsValue) throws {
        if !settings.contains(where: { $0.key == key.rawValue }) {
            let setting = Setting(key: key.rawValue, value: value.value())
            _ = try setting.save(on: database).wait()
        }
    }

    private func ensureRoleExists(on database: Database,
                                  existing roles: [Role],
                                  code: String,
                                  title: String,
                                  description: String,
                                  hasSuperPrivileges: Bool,
                                  isDefault: Bool) throws {
        if !roles.contains(where: { $0.code == code }) {
            let role = Role(code: code, title: title, description: description, hasSuperPrivileges: hasSuperPrivileges, isDefault: isDefault)
            _ = try role.save(on: database).wait()
        }
    }
    
    private func ensureAdminExist(on database: Database) throws {
        let admin = try User.query(on: database).filter(\.$userName == "admin").first().wait()
        
        if admin == nil {
            let appplicationSettings = self.settings.get(ApplicationSettings.self)

            let domain = appplicationSettings?.domain ?? "localhost"
            let baseAddress = appplicationSettings?.baseAddress ?? "http://\(domain)"
            
            let salt = App.Password.generateSalt()
            let passwordHash = try App.Password.hash("admin", withSalt: salt)
            let emailConfirmationGuid = UUID.init().uuidString
            let gravatarHash = UsersService().createGravatarHash(from: "admin@\(domain)")
            
            let (privateKey, publicKey) = try CryptoService().generateKeys()
            
            let user = User(isLocal: true,
                            userName: "admin",
                            account: "admin@\(domain)",
                            activityPubProfile: "\(baseAddress)/accounts/admin",
                            email: "admin@\(domain)",
                            name: "Administrator",
                            password: passwordHash,
                            salt: salt,
                            emailWasConfirmed: true,
                            isBlocked: false,
                            emailConfirmationGuid: emailConfirmationGuid,
                            gravatarHash: gravatarHash,
                            privateKey: privateKey,
                            publicKey: publicKey)

            _ = try user.save(on: database).wait()

            if let administratorRole = try Role.query(on: database).filter(\.$code == "administrator").first().wait() {
                try user.$roles.attach(administratorRole, on: database).wait()
            }
        }
    }
}
