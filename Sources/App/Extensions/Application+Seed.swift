//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application {

    func seedDictionaries() async throws {
        let database = self.db
        try await settings(on: database)
        try await roles(on: database)
    }
    
    func seedAdmin() async throws {
        let database = self.db
        try await users(on: database)
    }

    private func settings(on database: Database) async throws {
        let settings = try await Setting.query(on: database).all()

        // General.
        try await ensureSettingExists(on: database, existing: settings, key: .isRegistrationOpened, value: .boolean(true))
        try await ensureSettingExists(on: database, existing: settings, key: .corsOrigin, value: .string(""))
        
        // Recaptcha.
        try await ensureSettingExists(on: database, existing: settings, key: .isRecaptchaEnabled, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .recaptchaKey, value: .string(""))
        
        // Events.
        try await ensureSettingExists(on: database,
                                      existing: settings,
                                      key: .eventsToStore,
                                      value: .string(EventType.allCases.map { item -> String in item.rawValue }.joined(separator: ",")))

        // JWT keys.
        let (privateKey, publicKey) = try CryptoService().generateKeys()
        try await ensureSettingExists(on: database, existing: settings, key: .jwtPrivateKey, value: .string(privateKey))
        try await ensureSettingExists(on: database, existing: settings, key: .jwtPublicKey, value: .string(publicKey))
        
        // Email server.
        try await ensureSettingExists(on: database, existing: settings, key: .emailHostname, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .emailPort, value: .int(465))
        try await ensureSettingExists(on: database, existing: settings, key: .emailUserName, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .emailPassword, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .emailSecureMethod, value: .string(""))
    }

    private func roles(on database: Database) async throws {
        let roles = try await Role.query(on: database).all()

        try await ensureRoleExists(on: database,
                                   existing: roles,
                                   code: "administrator",
                                   title: "Administrator",
                                   description: "Users have access to whole system.",
                                   hasSuperPrivileges: true,
                                   isDefault: false)

        try await ensureRoleExists(on: database,
                                   existing: roles,
                                   code: "member",
                                   title: "Member",
                                   description: "Users have access to public part of system.",
                                   hasSuperPrivileges: false,
                                   isDefault: true)
    }
    
    private func users(on database: Database) async throws {
        try await ensureAdminExist(on: database)
    }

    private func ensureSettingExists(on database: Database, existing settings: [Setting], key: SettingKey, value: SettingsValue) async throws {
        if !settings.contains(where: { $0.key == key.rawValue }) {
            let setting = Setting(key: key.rawValue, value: value.value())
            _ = try await setting.save(on: database)
        }
    }

    private func ensureRoleExists(on database: Database,
                                  existing roles: [Role],
                                  code: String,
                                  title: String,
                                  description: String,
                                  hasSuperPrivileges: Bool,
                                  isDefault: Bool) async throws {
        if !roles.contains(where: { $0.code == code }) {
            let role = Role(code: code, title: title, description: description, hasSuperPrivileges: hasSuperPrivileges, isDefault: isDefault)
            _ = try await role.save(on: database)
        }
    }
    
    private func ensureAdminExist(on database: Database) async throws {
        let admin = try await User.query(on: database).filter(\.$userName == "admin").first()
        
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
                            activityPubProfile: "\(baseAddress)/actors/admin",
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

            _ = try await user.save(on: database)

            if let administratorRole = try await Role.query(on: database).filter(\.$code == "administrator").first() {
                try await user.$roles.attach(administratorRole, on: database)
            }
        }
    }
}
