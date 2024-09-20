//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct TwoFactorTokensServiceKey: StorageKey {
        typealias Value = TwoFactorTokensServiceType
    }

    var twoFactorTokensService: TwoFactorTokensServiceType {
        get {
            self.application.storage[TwoFactorTokensServiceKey.self] ?? TwoFactorTokensService()
        }
        nonmutating set {
            self.application.storage[TwoFactorTokensServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol TwoFactorTokensServiceType: Sendable {
    func generate(for user: User, withId id: Int64) throws -> TwoFactorToken
    func validate(_ input: String, twoFactorToken: TwoFactorToken, allowBackupCode: Bool) throws -> Bool
    func find(for userId: Int64, on database: Database) async throws -> TwoFactorToken?
}

/// A service for managing two factor tokens in the system.
final class TwoFactorTokensService: TwoFactorTokensServiceType {

    func generate(for user: User, withId id: Int64) throws -> TwoFactorToken {
        let key = Data([UInt8].random(count: 16)).base32EncodedString()
        
        guard let data = Data(base32Encoded: key) else {
            throw TwoFactorTokenError.cannotEncodeKey
        }
        
        let symetrickey = SymmetricKey(data: data)
        let hotp = HOTP(key: symetrickey, digest: .sha1, digits: .six)
        let backupTokens = (1...10).map {
            hotp.generate(counter: $0)
        }

        return try TwoFactorToken(id: id, userId: user.requireID(), key: key, backupTokens: backupTokens)
    }
    
    func validate(_ input: String, twoFactorToken: TwoFactorToken, allowBackupCode: Bool = true) throws -> Bool {
        let tokens = try self.generateTokens(key: twoFactorToken.key)
        return tokens.contains(input) || (allowBackupCode && twoFactorToken.backupTokens.contains(input))
    }
    
    func find(for userId: Int64, on database: Database) async throws -> TwoFactorToken? {
        return try await TwoFactorToken.query(on: database)
            .filter(\.$user.$id == userId)
            .first()
    }
    
    internal func generateTokens(key: String) throws -> [String] {
        let totpToken = try self.generateTotpToken(with: key)
        return totpToken.generate(time: Date(), range: 1)
    }
    
    private func generateTotpToken(with key: String) throws -> TOTP {
        guard let keyData = Data(base32Encoded: key) else {
            throw TwoFactorTokenError.cannotEncodeKey
        }
        
        let key = SymmetricKey(data: keyData)
        return TOTP(key: key, digest: .sha1, digits: .six, interval: 30)
    }
}
