//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct PersonImageDto {
    public let type = "Image"
    public let mediaType: String?
    public let url: String
    
    public init(mediaType: String, url: String) {
        self.mediaType = mediaType
        self.url = url
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case mediaType
        case url
    }
}

extension PersonImageDto: Codable { }
extension PersonImageDto: Sendable { }
