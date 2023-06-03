//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application {

    func seedDatabase() throws {
        let database = self.db
        try settings(on: database)
        try roles(on: database)
        try users(on: database)
    }

    private func settings(on database: Database) throws {
        let settings = try Setting.query(on: database).all().wait()

        try ensureSettingExists(on: database, existing: settings, key: .baseAddress, value: "http://localhost:8000")
        try ensureSettingExists(on: database, existing: settings, key: .domain, value: "localhost:8000")
        try ensureSettingExists(on: database, existing: settings, key: .emailServiceAddress, value: "http://localhost:8002")
        try ensureSettingExists(on: database, existing: settings, key: .isRecaptchaEnabled, value: "0")
        try ensureSettingExists(on: database, existing: settings, key: .recaptchaKey, value: "")
        try ensureSettingExists(on: database,
                                existing: settings,
                                key: .eventsToStore,
                                value: EventType.allCases.map { item -> String in item.rawValue }.joined(separator: ","))
        try ensureSettingExists(on: database, existing: settings, key: .corsOrigin, value: "")
        try ensureSettingExists(on: database, existing: settings, key: .jwtPrivateKey, value:
"""
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAh4WjL2kJmM2GwSp1h/SMyrx7hD99Hl5vdNqlEhJ7mpg7UHzn
K0A3nroOqo4Z8idkfM0kjTLFqlHdo1HU5jBmibfuTo8CpAwqKi6Ff+sR9mJd8QkQ
nPRmHgRg5hvbt8h1zHZokiKFUG0P5bCoZ/bgzHEXIVYZ3Y+htcvZwSIpZBqjZ/Qm
HjIk9Q7gKlcVUOgBuagerpvxELD4viOu7OETV3bpVa5boL55jJoxHmpUKiPaytOi
x8eRvi8YjUNf3uQ5y9ye+891BEsVxcjLDyHMUKcpj5e1EysLDLJJQsbRUElO0CCs
quATzcGbPz3pmF/5Wn1mRr+GoLD72Hr4wR9/MwIDAQABAoIBAHAY4Sc5KeADuQAU
n80KQl770utMHLE/CdBNfpbZRPZWD1H/TrOe1aLsYW9ARUPgw6Tbhu1oXsoIF12d
NY4F4PrvciX28wdArKvheTma9munZ+8VQXGiUslnc8NCrdZx8MZj9xFRjpY88BZc
rp/4PG++55QChTiYMvmOGZtAJ56NltJ8mDH/HPmHqrRqHTRy1Vvrm/zAxfZo8C9u
IFuGa6v2/apMhq5joRNcCrlLPUr6hJbaFIBzfKUUyF/7p8tx1YgSCxanjWTEh0gw
9dwx4Qr8aKIhleTB9fEHF0dtEJMfQDnnPZCCPKyZqPBAsprodglXFsTJFVrp6whh
V+24iHkCgYEA11sJ0OZTLTu2SAFL2PhmruQC8p0FPNkFJSsV6PMU+7cGAtgpVNN5
LeudTIpvBjSXtSpz6VugRxhiLWlXH1+9a//KT1DqIsJKtZjh/gscFQ7orLtseX2v
0EYB+80gL9aQtufZgKCz6TjHO1+SS7m4zInVijpqoGhQuNjuv1QQTtUCgYEAoRlr
IU+UvEPhl4gnt/yRbZalz2N/CBeezJG8GW7K5ru1yeYuxCKeSIfuDynkRmgsBfXp
2GFkG2WQQZ6CJ0YGk/KK77L32h8fKUOQQu9UaOvV7BoEjj++6JwsFOQ3X88JtGu8
KgPV/qPj1hxFT1ZIOu5y+haeLCB5bsTzHHVHaecCgYBV1zD7dsOS1SlcXD/qdWEg
tzxBjrtGvM6jOSBboYEssJCR063t5Pl5h2BE4S1OEOqjyQ845k/l5t9DcKjMlbIA
eY4fvYYGYuG6rvzt8Wm5Lx8psu+TIblR0IX745C/4MwATDxTXDs6bGplzTuYOahi
x1I57f0QgWQjujy4QP7bHQKBgDqpPtFKYSaMsUC0W4Irfekhyg7SdBdGQpTLHGtG
ZKvP/koefzj8Qha3KIBtCKp6lE03VodsLz+qo/TA+zPB0/NbhivyRz4txvMHnyhA
bcQm3Ca08qO5opKhC4wv7dn9UdNYx5OlAe9PTk9QzAwvpu2Oll9qjP4UdSNYpA3g
xrhRAoGAJjk4/TcoOMzSjaiMF3yq82CRblUvpo0cWLN/nLWkwJkhCgzf/fm7Z3Fs
2GosCdIK/krdgKYUThj02OmSB58oYCNn6W56G07yzDVeTIp0BrlsPuCMqGILabKP
4SlNoO/RqfjpSZRMnEpYPbrxgYkjC9nPB+Zy6mRCN7cYqJoqjng=
-----END RSA PRIVATE KEY-----
""")
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

    private func ensureSettingExists(on database: Database, existing settings: [Setting], key: SettingKey, value: String) throws {
        if !settings.contains(where: { $0.key == key.rawValue }) {
            let setting = Setting(key: key.rawValue, value: value)
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
            let domain = "localhost"
            let baseAddress = "https://\(domain)"
            
            let salt = App.Password.generateSalt()
            let passwordHash = try App.Password.hash("admin", withSalt: salt)
            let emailConfirmationGuid = UUID.init().uuidString
            let gravatarHash = UsersService().createGravatarHash(from: "admin@\(domain)")
            
            let (privateKey, publicKey) = try CryptoService().generateKeys()
            
            let user = User(userName: "admin",
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
