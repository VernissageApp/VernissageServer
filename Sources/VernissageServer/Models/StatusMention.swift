//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Status mention.
final class StatusMention: Model, @unchecked Sendable {
    static let schema: String = "StatusMentions"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "userName")
    var userName: String

    @Field(key: "userNameNormalized")
    var userNameNormalized: String
    
    @Parent(key: "statusId")
    var status: Status
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, statusId: Int64, userName: String) {
        self.init()

        self.id = id
        self.$status.id = statusId
        self.userName = userName
        self.userNameNormalized = userName.uppercased()
    }
}

/// Allows `StatusMention` to be encoded to and decoded from HTTP messages.
extension StatusMention: Content { }

extension NoteTagDto {
    init(userName: String, activityPubProfile: String) {
        self.init(
            type: "Mention",
            name: "@\(userName)",
            href: activityPubProfile)
    }
}
