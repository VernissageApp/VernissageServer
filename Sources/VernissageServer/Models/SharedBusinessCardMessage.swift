//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User's shared business card message.
final class SharedBusinessCardMessage: Model, @unchecked Sendable {
    static let schema: String = "SharedBusinessCardMessages"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "sharedBusinessCardId")
    var sharedBusinessCard: SharedBusinessCard

    @OptionalParent(key: "userId")
    var user: User?
    
    @Field(key: "message")
    var message: String

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }

    convenience init(id: Int64,
                     sharedBusinessCardId: Int64,
                     userId: Int64? = nil,
                     message: String
    ) {
        self.init()

        self.id = id
        self.$sharedBusinessCard.id = sharedBusinessCardId
        self.$user.id = userId
        self.message = message
    }
}

/// Allows `SharedBusinessCardMessage` to be encoded to and decoded from HTTP messages.
extension SharedBusinessCardMessage: Content { }
