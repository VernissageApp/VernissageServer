//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct MediaAttachmentDto {
    public let type = "Document"
    public let mediaType: String
    public let url: String
    public let name: String?
    public let blurhash: String?
    public let width: Int?
    public let height: Int?
    public let exif: MediaExifDto?
    public let location: MediaLocationDto?
    
    public init(mediaType: String, url: String, name: String?, blurhash: String?, width: Int?, height: Int?, exif: MediaExifDto?, location: MediaLocationDto?) {
        self.mediaType = mediaType
        self.url = url
        self.name = name
        self.blurhash = blurhash
        self.width = width
        self.height = height
        self.exif = exif
        self.location = location
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case mediaType
        case url
        case name
        case blurhash
        case width
        case height
        case exif
        case location
    }
}

extension MediaAttachmentDto: Codable { }
