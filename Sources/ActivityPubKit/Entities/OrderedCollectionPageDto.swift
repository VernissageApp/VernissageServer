//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct OrderedCollectionPageDto: BaseOrderedCollectionDto {
    public let context = "https://www.w3.org/ns/activitystreams"
    public let type = "OrderedCollectionPage"

    public let id: String
    public let totalItems: Int
    public let prev: String?
    public let next: String?
    public let partOf: String
    public let orderedItems: [String]
    
    public init(id: String,
                totalItems: Int,
                prev: String?,
                next: String?,
                partOf: String,
                orderedItems: [String]
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

extension OrderedCollectionPageDto: Codable { }
