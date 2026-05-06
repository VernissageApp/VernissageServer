//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct OrderedCollectionPageDto: Codable, Sendable {
    public let context = "https://www.w3.org/ns/activitystreams"
    public let type = "OrderedCollectionPage"

    public let id: String
    public let totalItems: Int
    public let prev: String?
    public let next: String?
    public let partOf: String
    public let orderedItems: ComplexType<ObjectDto>
    
    public init(id: String,
                totalItems: Int,
                prev: String?,
                next: String?,
                partOf: String,
                orderedItems: ComplexType<ObjectDto>
    ) {
        self.id = id
        self.totalItems = totalItems
        self.prev = prev
        self.next = next
        self.partOf = partOf
        self.orderedItems = orderedItems
    }
    
    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case totalItems
        case next
        case prev
        case partOf
        case orderedItems
    }
}

extension OrderedCollectionPageDto {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.totalItems = try container.decodeIfPresent(Int.self, forKey: .totalItems) ?? 0
        self.prev = try container.decodeFlexibleLinkIfPresent(forKey: .prev)
        self.next = try container.decodeFlexibleLinkIfPresent(forKey: .next)
        self.partOf = try container.decodeFlexibleLinkIfPresent(forKey: .partOf) ?? ""
        self.orderedItems = try container.decodeIfPresent(ComplexType<ObjectDto>.self, forKey: .orderedItems) ?? .multiple([])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.context, forKey: .context)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.totalItems, forKey: .totalItems)
        try container.encodeIfPresent(self.next, forKey: .next)
        try container.encodeIfPresent(self.prev, forKey: .prev)
        try container.encode(self.partOf, forKey: .partOf)
        try container.encode(self.orderedItems, forKey: .orderedItems)
    }
}

private struct FlexibleLinkDto: Codable {
    let id: String?
    let href: String?
}

private extension KeyedDecodingContainer {
    func decodeFlexibleLinkIfPresent(forKey key: Key) throws -> String? {
        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }

        if let linkValue = try decodeIfPresent(FlexibleLinkDto.self, forKey: key) {
            return linkValue.id ?? linkValue.href
        }

        return nil
    }
}
