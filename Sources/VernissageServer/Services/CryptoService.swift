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
    /// Generates a new RSA key pair (private and public keys) in PEM format.
    ///
    /// - Returns: A tuple containing the private key and public key as PEM-encoded strings.
    /// - Throws: An error if key generation fails.
    func generateKeys() throws -> (privateKey: String, publicKey: String)
    
    /// Verifies a digital signature for the given digest using the provided public key in PEM format.
    ///
    /// - Parameters:
    ///   - publicKeyPem: The PEM-encoded public key string.
    ///   - signatureData: The signature data to be verified.
    ///   - digest: The digest (hashed data) that was signed.
    /// - Returns: True if the signature is valid, false otherwise.
    /// - Throws: An error if the verification process fails.
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
    
    private func generateSignatureBase64(privateKeyPem: String, digest: Data) throws -> String {
        let privateKey = try _RSA.Signing.PrivateKey(pemRepresentation: privateKeyPem)
        let signature = try privateKey.signature(for: digest, padding: .insecurePKCS1v1_5)
        
        return signature.rawRepresentation.base64EncodedString()
    }
}
