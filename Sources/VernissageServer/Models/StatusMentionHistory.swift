//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Status mention (history).
final class StatusMentionHistory: Model, @unchecked Sendable {
    static let schema: String = "StatusMentionHistories"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "userName")
    var userName: String

    @Field(key: "userNameNormalized")
    var userNameNormalized: String

    @Field(key: "userUrl")
    var userUrl: String?
    
    @Parent(key: "statusHistoryId")
    var statusHistory: StatusHistory
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, statusHistoryId: Int64, from statusMention: StatusMention) {
        self.init()
        
        self.id = id
        self.$statusHistory.id = statusHistoryId

        self.userName = statusMention.userName
        self.userNameNormalized = statusMention.userNameNormalized
        self.userUrl = statusMention.userUrl
    }
}

/// Allows `StatusMentionHistory` to be encoded to and decoded from HTTP messages.
extension StatusMentionHistory: Content { }

extension [StatusMentionHistory] {
    func toDictionary() -> [String: String]? {
        let mentions = self.filter { $0.userUrl != nil && $0.userUrl?.isEmpty == false }
        if mentions.count == 0 {
            return nil
        }
        
        return Dictionary(uniqueKeysWithValues: mentions.map { ("\($0.userNameNormalized.trimmingPrefix("@"))", $0.userUrl ?? "") })
    }
}
