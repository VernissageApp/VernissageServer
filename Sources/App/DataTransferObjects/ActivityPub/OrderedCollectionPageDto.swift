//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct OrderedCollectionPageDto: BaseOrderedCollectionDto {
    public let context = "https://www.w3.org/ns/activitystreams"
    public let type = "OrderedCollectionPage"

    public let id: String
    public let totalItems: Int
    public let prev: String?
    public let next: String?
    public let partOf: String
    public let orderedItems: [String]
    
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
