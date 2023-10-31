//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct NoteHashtagDto {
    public let type = "Hashtag"
    public let name: String
    public let href: String
    
    public init(name: String, href: String) {
        self.name = name
        self.href = href
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case name
        case href
    }
}

extension NoteHashtagDto: Codable { }
