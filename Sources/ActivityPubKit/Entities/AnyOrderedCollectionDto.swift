//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public enum AnyOrderedCollectionDto: Codable, Sendable {
    case orderedCollection(OrderedCollectionDto)
    case orderedCollectionPage(OrderedCollectionPageDto)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: OrderedCollectionTypeCodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "OrderedCollection":
            self = .orderedCollection(try OrderedCollectionDto(from: decoder))
        case "OrderedCollectionPage":
            self = .orderedCollectionPage(try OrderedCollectionPageDto(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type,
                                                   in: container,
                                                   debugDescription: "Unsupported ordered collection type '\(type)'.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .orderedCollection(let orderedCollection):
            try orderedCollection.encode(to: encoder)
        case .orderedCollectionPage(let orderedCollectionPage):
            try orderedCollectionPage.encode(to: encoder)
        }
    }
}

private enum OrderedCollectionTypeCodingKeys: String, CodingKey {
    case type
}
