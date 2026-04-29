//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public protocol BaseOrderedCollectionDto: Sendable {
}

public struct OrderedCollectionDto: BaseOrderedCollectionDto {
    public let context = "https://www.w3.org/ns/activitystreams"
    public let type = "OrderedCollection"

    public let id: String
    public let totalItems: Int
    public let first: String?
    public let orderedItems: [String]?
    
    public init(id: String, totalItems: Int, first: String?, orderedItems: [String]? = nil) {
        self.id = id
        self.totalItems = totalItems
        self.first = first
        self.orderedItems = orderedItems
    }
    
    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case totalItems
        case first
        case orderedItems
    }
}

extension OrderedCollectionDto: Codable { }
