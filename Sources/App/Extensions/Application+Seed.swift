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
        try await localizables(on: database)
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
            let appplicationSettings = self.settings.cached

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
                            locale: "en_US",
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
    
    private func localizables(on database: Database) async throws {
        let localizables = try await Localizable.query(on: database).all()
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.confirmEmail.subject",
                                          locale: "en_US",
                                          system: "Vernissage - Confirm email")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.confirmEmail.body",
                                          locale: "en_US",
                                          system:
"""
<html>
    <body>
        <div>Hi {name},</div>
        <div>Please confirm your account by clicking following <a href='{redirectBaseUrl}confirm-email?token={token}&user={userId}'>link</a>.</div>
    </body>
</html>
""")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.forgotPassword.subject",
                                          locale: "en_US",
                                          system: "Vernissage - Reset password")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.forgotPassword.body",
                                          locale: "en_US",
                                          system:
"""
<html>
    <body>
        <div>Hi {name},</div>
        <div>You can reset your password by clicking following <a href='{redirectBaseUrl}reset-password?token={token}'>link</a>.</div>
    </body>
</html>
""")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.confirmEmail.subject",
                                          locale: "pl_PL",
                                          system: "Vernissage - Confirm email")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.confirmEmail.body",
                                          locale: "pl_PL",
                                          system:
"""
<html>
    <body>
        <div>Cześć {name},</div>
        <div>Potwierdź swój adres email poprzez kliknięcie w <a href='{redirectBaseUrl}confirm-email?token={token}&user={userId}'>link</a>.</div>
    </body>
</html>
""")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.forgotPassword.subject",
                                          locale: "pl_PL",
                                          system: "Vernissage - Zresetuj hasło")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.forgotPassword.body",
                                          locale: "pl_PL",
                                          system:
"""
<html>
    <body>
        <div>Cześć {name},</div>
        <div>Możesz ustawić nowe hasło po kliknięciu w <a href='{redirectBaseUrl}reset-password?token={token}'>link</a>.</div>
    </body>
</html>
""")
    }
    
    private func ensureLocalizableExists(on database: Database,
                                         existing localizables: [Localizable],
                                         code: String,
                                         locale: String,
                                         system: String) async throws {
        if !localizables.contains(where: { $0.code == code && $0.locale == locale }) {
            let localizable = Localizable(code: code, locale: locale, system: system)
            _ = try await localizable.save(on: database)
        }
    }
}
