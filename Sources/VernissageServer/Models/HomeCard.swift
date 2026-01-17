//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Home card data.
final class HomeCard: Model, @unchecked Sendable {
    static let schema: String = "HomeCards"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "body")
    var body: String

    @Field(key: "order")
    var order: Int
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64,
                     title: String,
                     body: String,
                     order: Int) {
        self.init()

        self.id = id
        self.title = title
        self.body = body
        self.order = order
    }
}

/// Allows `HomeCard` to be encoded to and decoded from HTTP messages.
extension HomeCard: Content { }

extension HomeCardDto {
    init?(from homeCard: HomeCard?) {
        guard let homeCard else {
            return nil
        }
        
        self.init(
            id: homeCard.stringId(),
            title: homeCard.title,
            body: homeCard.body,
            order: homeCard.order
        )
    }
}
