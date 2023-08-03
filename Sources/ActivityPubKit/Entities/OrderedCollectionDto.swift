//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public protocol BaseOrderedCollectionDto {
}

public struct OrderedCollectionDto: BaseOrderedCollectionDto {
    public let context = "https://www.w3.org/ns/activitystreams"
    public let type = "OrderedCollection"

    public let id: String
    public let totalItems: Int
    public let first: String?
    
    public init(id: String, totalItems: Int, first: String?) {
        self.id = id
        self.totalItems = totalItems
        self.first = first
    }
    
    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case totalItems
        case first
    }
}

extension OrderedCollectionDto: Codable { }
