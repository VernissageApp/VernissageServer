//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

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
    private let rsaPrivatePrefix = "-----BEGIN RSA PRIVATE KEY-----\n"
    private let rsaPrivateSuffix = "\n-----END RSA PRIVATE KEY-----"
    
    private let rsaPublicPrefix = "-----BEGIN RSA PUBLIC KEY-----\n"
    private let rsaPublicSuffix = "\n-----END RSA PUBLIC KEY-----"
    
    public func generateKeys() throws -> (privateKey: String, publicKey: String) {
        var error: Unmanaged<CFError>?

        let publicKeyAttributes: [NSObject: NSObject] = [
            kSecAttrIsPermanent: true as NSObject,
            kSecAttrApplicationTag: "photos.vernissage.public".data(using: String.Encoding.utf8)! as NSObject,
            kSecClass: kSecClassKey,
            kSecReturnData: kCFBooleanTrue
        ]

        let privateKeyAttributes: [NSObject: NSObject] = [
            kSecAttrIsPermanent:true as NSObject,
            kSecAttrApplicationTag:"photos.vernissage.private".data(using: String.Encoding.utf8)! as NSObject,
            kSecClass: kSecClassKey,
            kSecReturnData: kCFBooleanTrue
        ]

        var keyPairAttr = [NSObject: NSObject]()
        keyPairAttr[kSecAttrKeyType] = kSecAttrKeyTypeRSA
        keyPairAttr[kSecAttrKeySizeInBits] = 2048 as NSObject
        keyPairAttr[kSecPublicKeyAttrs] = publicKeyAttributes as NSObject
        keyPairAttr[kSecPrivateKeyAttrs] = privateKeyAttributes as NSObject
        
        guard let privateKey = SecKeyCreateRandomKey(keyPairAttr as CFDictionary, &error) else {
            throw CryptoError.privateKeyNotGenerated
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CryptoError.publicKeyNotGenerated
        }
                
        guard let privateKeyExternalRepresentation = SecKeyCopyExternalRepresentation(privateKey, &error) else {
            throw CryptoError.externalPrivateKeyNotGenerated
        }

        guard let publicKeyExternalRepresentation = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw CryptoError.externalPublicKeyNotGenerated
        }
        
        guard let privateKeyData = privateKeyExternalRepresentation as Data? else {
            throw CryptoError.base64PrivateKeyNotGenerated
        }
        
        guard let publicKeyData = publicKeyExternalRepresentation as Data? else {
            throw CryptoError.base64PublicKeyNotGenerated
        }
        
        let privateKeyBase64 = rsaPrivatePrefix + privateKeyData.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed]) + rsaPrivateSuffix
        let publicKeyBase64 = rsaPublicPrefix + publicKeyData.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed]) + rsaPublicSuffix
        
        return (privateKeyBase64, publicKeyBase64)
    }
}
