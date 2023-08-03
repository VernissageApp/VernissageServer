//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct PersonAttachmentDto {
    public let type = "PropertyValue"
    public let name: String
    public let value: String
    
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case name
        case value
    }
}

extension PersonAttachmentDto: Codable { }
