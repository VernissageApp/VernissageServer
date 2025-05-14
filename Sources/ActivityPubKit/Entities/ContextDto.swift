//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public final class ContextDto {
    public let value: String?
    public let manuallyApprovesFollowers: String?
    public let toot: String?
    public let schema: String?
    public let propertyValue: String?
    public let alsoKnownAs: AlsoKnownAs?
    public let votersCount: String?
    public let blurhash: String?
    public let photos: String?
    public let location: String?
    public let metadata: String?
    public let category: String?
    
    enum CodingKeys: String, CodingKey {
        case value
        case manuallyApprovesFollowers
        case toot
        case schema
        case propertyValue = "PropertyValue"
        case alsoKnownAs
        case votersCount
        case blurhash
        case photos
        case location
        case metadata
        case category
    }
    
    public init(value: String) {
        self.value = value
        self.manuallyApprovesFollowers = nil
        self.toot = nil
        self.alsoKnownAs = nil
        self.schema = nil
        self.propertyValue = nil
        self.votersCount = nil
        self.blurhash = nil
        self.photos = nil
        self.location = nil
        self.metadata = nil
        self.category = nil
    }
    
    fileprivate init(
        manuallyApprovesFollowers: String? = nil,
        toot: String? = nil,
        schema: String? = nil,
        propertyValue: String? = nil,
        alsoKnownAs: AlsoKnownAs? = nil,
        votersCount: String? = nil,
        blurhash: String? = nil,
        photos: String? = nil,
        location: String? = nil,
        metadata: String? = nil,
        category: String? = nil
    ) {
        self.value = nil
        self.manuallyApprovesFollowers = manuallyApprovesFollowers
        self.toot = toot
        self.alsoKnownAs = alsoKnownAs
        self.schema = schema
        self.propertyValue = propertyValue
        self.votersCount = votersCount
        self.blurhash = blurhash
        self.photos = photos
        self.location = location
        self.metadata = metadata
        self.category = category
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self.value = try container.decode(String.self)
            self.manuallyApprovesFollowers = nil
            self.toot = nil
            self.alsoKnownAs = nil
            self.schema = nil
            self.propertyValue = nil
            self.votersCount = nil
            self.blurhash = nil
            self.photos = nil
            self.location = nil
            self.metadata = nil
            self.category = nil
        } catch DecodingError.typeMismatch {
            if let objectData = try? container.decode(ContextDataDto.self) {
                self.value = ""
                self.manuallyApprovesFollowers = objectData.manuallyApprovesFollowers
                self.toot = objectData.toot
                self.alsoKnownAs = objectData.alsoKnownAs
                self.schema = objectData.schema
                self.propertyValue = objectData.propertyValue
                self.votersCount = objectData.votersCount
                self.blurhash = objectData.blurhash
                self.photos = objectData.photos
                self.location = objectData.location
                self.metadata = objectData.metadata
                self.category = objectData.category
            } else {
                self.value = nil
                self.manuallyApprovesFollowers = nil
                self.toot = nil
                self.alsoKnownAs = nil
                self.schema = nil
                self.propertyValue = nil
                self.votersCount = nil
                self.blurhash = nil
                self.photos = nil
                self.location = nil
                self.metadata = nil
                self.category = nil
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        if self.value == nil {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(self.manuallyApprovesFollowers, forKey: .manuallyApprovesFollowers)
            try container.encodeIfPresent(self.toot, forKey: .toot)
            try container.encodeIfPresent(self.schema, forKey: .schema)
            try container.encodeIfPresent(self.propertyValue, forKey: .propertyValue)
            try container.encodeIfPresent(self.alsoKnownAs, forKey: .alsoKnownAs)
            try container.encodeIfPresent(self.votersCount, forKey: .votersCount)
            try container.encodeIfPresent(self.blurhash, forKey: .blurhash)
            try container.encodeIfPresent(self.photos, forKey: .photos)
            try container.encodeIfPresent(self.location, forKey: .location)
            try container.encodeIfPresent(self.metadata, forKey: .metadata)
            try container.encodeIfPresent(self.category, forKey: .category)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(self.value)
        }
    }
}

extension ContextDto: Equatable {
    public static func == (lhs: ContextDto, rhs: ContextDto) -> Bool {
        return lhs.value == rhs.value
    }
}

extension ContextDto: Codable { }
extension ContextDto: Sendable { }

final fileprivate class ContextDataDto {
    public let manuallyApprovesFollowers: String?
    public let toot: String?
    public let schema: String?
    public let propertyValue: String?
    public let alsoKnownAs: AlsoKnownAs?
    public let votersCount: String?
    public let blurhash: String?
    public let photos: String?
    public let location: String?
    public let metadata: String?
    public let category: String?
    
    enum CodingKeys: String, CodingKey {
        case manuallyApprovesFollowers
        case toot
        case schema
        case propertyValue = "PropertyValue"
        case alsoKnownAs
        case votersCount
        case blurhash
        case photos
        case location
        case metadata
        case category
    }
}

extension ContextDataDto: Codable { }

public final class AlsoKnownAs: Sendable {
    public let id: String?
    public let type: String?
    
    init(id: String?, type: String?) {
        self.id = id
        self.type = type
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "@id"
        case type = "@type"
    }
}

extension AlsoKnownAs: Codable { }

extension ContextDto {
    public static func createPersonContext() -> ComplexType<ContextDto> {
        .multiple([
            ContextDto(value: "https://w3id.org/security/v1"),
            ContextDto(value: "https://www.w3.org/ns/activitystreams"),
            ContextDto(manuallyApprovesFollowers: "as:manuallyApprovesFollowers",
                       toot: "http://joinmastodon.org/ns#",
                       schema: "http://schema.org#",
                       propertyValue: "schema:PropertyValue",
                       alsoKnownAs: AlsoKnownAs(id: "as:alsoKnownAs", type: "@id"))
        ])
    }
    
    public static func createNoteContext() -> ComplexType<ContextDto> {
        .multiple([
            ContextDto(value: "https://www.w3.org/ns/activitystreams"),
            ContextDto(toot: "http://joinmastodon.org/ns#",
                       votersCount: "toot:votersCount",
                       blurhash: "toot:blurhash",
                       photos: "https://joinvernissage.org/ns#",
                       location: "photos:location",
                       metadata: "photos:metadata",
                       category: "photos:category")
        ])
    }
}
