//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct MediaAttachmentDto {
    public let type = "Image"
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
