//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct SignatureDto {
    public let type: String
    public let creator: String
    public let created: String
    public let signatureValue: String
    
    public init(type: String, creator: String, created: String, signatureValue: String) {
        self.type = type
        self.creator = creator
        self.created = created
        self.signatureValue = signatureValue
    }
}

extension SignatureDto: Codable { }
extension SignatureDto: Sendable { }
