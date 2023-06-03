//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import _CryptoExtras

extension Application.Services {
    struct CryptoServiceKey: StorageKey {
        typealias Value = CryptoServiceType
    }

    var cryptoService: CryptoServiceType {
        get {
            self.application.storage[CryptoServiceKey.self] ?? CryptoService()
        }
        nonmutating set {
            self.application.storage[CryptoServiceKey.self] = newValue
        }
    }
}

protocol CryptoServiceType {
    func generateKeys() throws -> (privateKey: String, publicKey: String)
}

final class CryptoService: CryptoServiceType {
    public func generateKeys() throws -> (privateKey: String, publicKey: String) {
        let privateKey = try _RSA.Signing.PrivateKey(keySize: .bits2048)        
        return (privateKey.pemRepresentation, privateKey.publicKey.pemRepresentation)
    }
}
