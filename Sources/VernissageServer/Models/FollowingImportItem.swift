//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Information about imported follow.
final class FollowingImportItem: Model, @unchecked Sendable {

    static let schema = "FollowingImportItems"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "followingImportId")
    var followingImport: FollowingImport
    
    @Field(key: "account")
    var account: String
    
    @Field(key: "showBoosts")
    var showBoosts: Bool
    
    @Field(key: "languages")
    var languages: String?
    
    @Field(key: "status")
    var status: FollowingImportItemStatus
    
    @Field(key: "errorMessage")
    var errorMessage: String?
    
    @Timestamp(key: "startedAt", on: .none)
    var startedAt: Date?

    @Timestamp(key: "endedAt", on: .none)
    var endedAt: Date?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    convenience init(id: Int64,
                     followingImportId: Int64,
                     account: String,
                     showBoosts: Bool,
                     languages: String?
    ) {
        self.init()

        self.id = id
        self.$followingImport.id = followingImportId
        self.account = account
        self.showBoosts = showBoosts
        self.languages = languages

        self.status = .notProcessed
    }
}

/// Allows `FollowingImportItem` to be encoded to and decoded from HTTP messages.
extension FollowingImportItem: Content { }
