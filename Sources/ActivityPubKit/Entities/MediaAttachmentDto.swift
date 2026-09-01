//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct MediaAttachmentDto {
    public let type: String
    public let mediaTypeRaw: String?
    public let url: String
    public let name: String?
    public let blurhash: String?
    public let width: Int?
    public let height: Int?
    public let exif: MediaExifDto?
    public let exifData: [MediaExifDataDto]?
    public let location: MediaLocationDto?
    public let hdrImageUrl: String?
    
    public init(mediaType: String,
                url: String,
                name: String?,
                blurhash: String?,
                width: Int?,
                height: Int?,
                hdrImageUrl: String?,
                exif: MediaExifDto?,
                exifData: [MediaExifDataDto]?,
                location: MediaLocationDto?
    ) {
        self.type = "Image"
        self.mediaTypeRaw = mediaType
        self.url = url
        self.name = name
        self.blurhash = blurhash
        self.width = width
        self.height = height
        self.exif = exif
        self.exifData = exifData
        self.location = location
        self.hdrImageUrl = hdrImageUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case mediaTypeRaw = "mediaType"
        case url
        case name
        case blurhash
        case width
        case height
        case exif
        case exifData
        case location
        case hdrImageUrl
    }

    private enum DecodingKeys: String, CodingKey {
        case type
        case mediaTypeRaw = "mediaType"
        case url
        case href
        case name
        case blurhash
        case width
        case height
        case exif
        case exifData
        case location
        case hdrImageUrl
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DecodingKeys.self)

        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "Image"
        self.mediaTypeRaw = try container.decodeIfPresent(String.self, forKey: .mediaTypeRaw)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.blurhash = try container.decodeIfPresent(String.self, forKey: .blurhash)
        self.width = try container.decodeIfPresent(Int.self, forKey: .width)
        self.height = try container.decodeIfPresent(Int.self, forKey: .height)
        self.exif = try container.decodeIfPresent(MediaExifDto.self, forKey: .exif)
        self.exifData = try container.decodeIfPresent([MediaExifDataDto].self, forKey: .exifData)
        self.location = try container.decodeIfPresent(MediaLocationDto.self, forKey: .location)
        self.hdrImageUrl = try container.decodeIfPresent(String.self, forKey: .hdrImageUrl)

        if let url = try container.decodeIfPresent(String.self, forKey: .url) {
            self.url = url
        } else {
            self.url = try container.decode(String.self, forKey: .href)
        }
    }
}

extension MediaAttachmentDto: Codable { }
extension MediaAttachmentDto: Sendable { }

extension MediaAttachmentDto {
    /// Some instances are not returning mediaType (only type).
    /// Howver we are using mediaType in all over the places and we need to expose it from that obejct.
    public var mediaType : String {
        if self.type == "Image" {
            return self.mediaTypeRaw ?? "image/jpeg"
        }
        
        return self.mediaTypeRaw ?? "unknown"
    }
    
    public func isSupportedImage() -> Bool {
        guard self.type != "Link" else {
            return false
        }

        let mediaTypeNormalized = self.mediaType.lowercased()
        return mediaTypeNormalized == "image/jpeg" || mediaTypeNormalized == "image/jpg" || mediaTypeNormalized == "image/png" || mediaTypeNormalized == "image/webp"
    }
}

extension [MediaAttachmentDto] {
    public func hasSupportedImages() -> Bool {
        self.contains(where: { $0.isSupportedImage() })
    }
    
    public func mediaTypes() -> String {
        self.map(\.mediaType).joined(separator: ", ")
    }
}
