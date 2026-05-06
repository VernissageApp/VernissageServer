//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct OrderedCollectionDto: Sendable {
    public let context = "https://www.w3.org/ns/activitystreams"
    public let type = "OrderedCollection"

    public let id: String
    public let totalItems: Int
    public let first: String?
    public let orderedItems: ComplexType<ObjectDto>?
    public let attributedTo: String?
    
    public init(id: String, totalItems: Int, first: String?, orderedItems: ComplexType<ObjectDto>? = nil, attributedTo: String? = nil) {
        self.id = id
        self.totalItems = totalItems
        self.first = first
        self.orderedItems = orderedItems
        self.attributedTo = attributedTo
    }
    
    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case totalItems
        case first
        case orderedItems
        case attributedTo
    }
}

extension OrderedCollectionDto: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.totalItems = try container.decodeIfPresent(Int.self, forKey: .totalItems) ?? 0
        self.first = try container.decodeFlexibleLinkIfPresent(forKey: .first)
        self.orderedItems = try container.decodeIfPresent(ComplexType<ObjectDto>.self, forKey: .orderedItems)
        self.attributedTo = try container.decodeFlexibleLinkIfPresent(forKey: .attributedTo)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.context, forKey: .context)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.totalItems, forKey: .totalItems)
        try container.encodeIfPresent(self.first, forKey: .first)
        try container.encodeIfPresent(self.orderedItems, forKey: .orderedItems)
        try container.encodeIfPresent(self.attributedTo, forKey: .attributedTo)
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
