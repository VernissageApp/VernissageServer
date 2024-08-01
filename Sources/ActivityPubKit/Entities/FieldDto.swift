//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct FieldDto {
    public let name: String?
    public let value: String?
    public let verifiedAt: String?
    
    public init(name: String?, value: String?, verifiedAt: String?) {
        self.name = name
        self.value = value
        self.verifiedAt = verifiedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case value
        case verifiedAt = "verified_at"
    }
}

public extension FieldDto {
    func isVerified() -> Bool {
        guard let verifiedAt else {
            return false
        }
        
        return !verifiedAt.isEmpty
    }
}

extension FieldDto: Codable { }
