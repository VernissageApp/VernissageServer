//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
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

@_documentation(visibility: private)
protocol CryptoServiceType: Sendable {
    func generateKeys() throws -> (privateKey: String, publicKey: String)
    func verifySignature(publicKeyPem: String, signatureData: Data, digest: Data) throws -> Bool
}

/// Cryptographic service.
final class CryptoService: CryptoServiceType {
    public func generateKeys() throws -> (privateKey: String, publicKey: String) {
        let privateKey = try _RSA.Signing.PrivateKey(keySize: .bits2048)        
        return (privateKey.pemRepresentation, privateKey.publicKey.pemRepresentation)
    }
    
    public func verifySignature(publicKeyPem: String, signatureData: Data, digest: Data) throws -> Bool {
        let publicKey = try _RSA.Signing.PublicKey(pemRepresentation: publicKeyPem)
        let signature = _RSA.Signing.RSASignature(rawRepresentation: signatureData)
        
        return publicKey.isValidSignature(signature, for: digest, padding: .insecurePKCS1v1_5)
    }
    
    public func generateSignatureBase64(privateKeyPem: String, digest: Data) throws -> String {
        let privateKey = try _RSA.Signing.PrivateKey(pemRepresentation: privateKeyPem)
        let signature = try privateKey.signature(for: digest, padding: .insecurePKCS1v1_5)
        
        return signature.rawRepresentation.base64EncodedString()
    }
}
