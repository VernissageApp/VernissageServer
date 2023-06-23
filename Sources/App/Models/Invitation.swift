//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class Invitation: Model {
    static let schema: String = "Invitations"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "code")
    var code: String
    
    @Parent(key: "userId")
    var user: User
    
    @OptionalParent(key: "invitedId")
    var invited: User?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: Int64? = nil, userId: Int64) {
        self.id = id ?? .init(bitPattern: Frostflake.generate())
        self.code = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        self.$user.id = userId
    }
}

/// Allows `Invitation` to be encoded to and decoded from HTTP messages.
extension Invitation: Content { }
