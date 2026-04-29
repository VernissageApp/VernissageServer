//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct CollectionDto: Sendable {
    public let context = "https://www.w3.org/ns/activitystreams"
    public let type = "Collection"
    
    public let id: String
    public let totalItems: Int
    public let items: [String]
    
    public init(id: String, totalItems: Int, items: [String]) {
        self.id = id
        self.totalItems = totalItems
        self.items = items
    }
    
    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case totalItems
        case items
    }
}

extension CollectionDto: Codable { }
