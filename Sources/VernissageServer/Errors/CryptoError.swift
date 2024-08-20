//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during encryption operations.
enum CryptoError: String, Error {
    case privateKeyNotGenerated
    case publicKeyNotGenerated
    case externalPrivateKeyNotGenerated
    case externalPublicKeyNotGenerated
    case base64PrivateKeyNotGenerated
    case base64PublicKeyNotGenerated
}

extension CryptoError: TerminateError {
    var status: HTTPResponseStatus {
        return .internalServerError
    }

    var reason: String {
        switch self {
        case .privateKeyNotGenerated: return "Cryptographic private key has not been generated."
        case .publicKeyNotGenerated: return "Cryptographic public key has not been generated."
        case .externalPrivateKeyNotGenerated: return "Cryptographic external private key has not been generated."
        case .externalPublicKeyNotGenerated: return "Cryptographic external public key has not been generated."
        case .base64PrivateKeyNotGenerated: return "Cryptographic base64 private key has not been generated."
        case .base64PublicKeyNotGenerated: return "Cryptographic base64 public key has not been generated."
        }
    }

    var identifier: String {
        return "crypto"
    }

    var code: String {
        return self.rawValue
    }
}
