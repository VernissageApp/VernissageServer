//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

/// Follow stores information about followers and following users.
///
/// sourceId -> targetId (**following**)
/// targetId -> sourceId (**followers**)
///
final class Follow: Model {

    static let schema = "Follows"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "sourceId")
    var source: User
    
    @Parent(key: "targetId")
    var target: User
    
    @Field(key: "approved")
    var approved: Bool

    @Field(key: "activityId")
    var activityId: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }
    
    convenience init(id: Int64? = nil,
                     sourceId: Int64,
                     targetId: Int64,
                     approved: Bool,
                     activityId: String?
    ) {
        self.init()

        self.$source.id = sourceId
        self.$target.id = targetId
        self.approved = approved
        self.activityId = activityId
    }
}

/// Allows `Follow` to be encoded to and decoded from HTTP messages.
extension Follow: Content { }
