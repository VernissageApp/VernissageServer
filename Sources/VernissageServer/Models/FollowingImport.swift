//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Information about imported follow.
final class FollowingImport: Model, @unchecked Sendable {

    static let schema = "FollowingImports"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "userId")
    var user: User
    
    @Field(key: "status")
    var status: FollowingImportStatus
    
    @Timestamp(key: "startedAt", on: .none)
    var startedAt: Date?

    @Timestamp(key: "endedAt", on: .none)
    var endedAt: Date?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    @Children(for: \.$followingImport)
    var followingImportItems: [FollowingImportItem]
    
    init() { }
    
    convenience init(id: Int64,
                     userId: Int64
    ) {
        self.init()

        self.id = id
        self.$user.id = userId

        self.status = .new
    }
}

/// Allows `FollowingImport` to be encoded to and decoded from HTTP messages.
extension FollowingImport: Content { }
