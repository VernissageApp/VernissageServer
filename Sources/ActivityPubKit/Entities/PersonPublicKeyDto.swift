//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct PersonPublicKeyDto {
    public let id: String
    public let owner: String
    public let publicKeyPem: String
    
    public init(id: String, owner: String, publicKeyPem: String) {
        self.id = id
        self.owner = owner
        self.publicKeyPem = publicKeyPem
    }
}

extension PersonPublicKeyDto: Codable { }
