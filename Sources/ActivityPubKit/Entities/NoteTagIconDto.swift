//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct NoteTagIconDto {
    public let type: String
    public let mediaType: String
    public let url: String
    
    public init(type: String, mediaType: String, url: String) {
        self.type = type
        self.mediaType = mediaType
        self.url = url
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case mediaType
        case url
    }
}

extension NoteTagIconDto: Codable { }
extension NoteTagIconDto: Sendable { }
