//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public struct NoteTagDto {
    public let type: String
    public let name: String
    public let id: String?
    public let href: String?
    public let updated: String?
    public let icon: NoteTagIconDto?
    
    public init(type: String, name: String, href: String) {
        self.type = type
        self.name = name
        self.href = href
        self.id = nil
        self.updated = nil
        self.icon = nil
    }
    
    public init(type: String, name: String, id: String, updated: Date, icon: NoteTagIconDto) {
        self.type = type
        self.name = name
        self.href = nil
        self.id = id
        self.updated = updated.toISO8601String()
        self.icon = icon
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case name
        case id
        case href
        case updated
        case icon
    }
}

extension NoteTagDto: Equatable {
    public static func == (lhs: NoteTagDto, rhs: NoteTagDto) -> Bool {
        return lhs.type == rhs.type && lhs.name == rhs.name && lhs.href == rhs.href
    }
}

extension NoteTagDto: Codable { }
extension NoteTagDto: Sendable { }
