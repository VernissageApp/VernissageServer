//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

protocol BaseOrderedCollectionDto: Content {
    
}

struct OrderedCollectionDto: BaseOrderedCollectionDto {
    public let context: String = "https://www.w3.org/ns/activitystreams"
    public let type: String = "OrderedCollection"

    public let id: String
    public let totalItems: Int
    public let first: String?
    
    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case totalItems
        case first
    }
}
