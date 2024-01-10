//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct NoteHashtagDto {
    public let type: String
    public let name: String
    public let href: String
    
    public init(type: String, name: String, href: String) {
        self.type = type
        self.name = name
        self.href = href
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case name
        case href
    }
}

extension NoteHashtagDto: Equatable {
    public static func == (lhs: NoteHashtagDto, rhs: NoteHashtagDto) -> Bool {
        return lhs.type == rhs.type && lhs.name == rhs.name && lhs.href == rhs.href
    }
}

extension NoteHashtagDto: Codable { }
