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

    @Field(key: "userUrl")
    var userUrl: String?
    
    @Parent(key: "statusId")
    var status: Status
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, statusId: Int64, userName: String, userUrl: String?) {
        self.init()
        let trimmedUserName = "\(userName.trimmingPrefix("@"))"
        
        self.id = id
        self.$status.id = statusId
        self.userName = trimmedUserName
        self.userNameNormalized = trimmedUserName.uppercased()
        self.userUrl = userUrl
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

extension [StatusMention] {
    func toDictionary() -> [String: String]? {
        let mentions = self.filter { $0.userUrl != nil && $0.userUrl?.isEmpty == false }
        if mentions.count == 0 {
            return nil
        }
        
        var uniqueMentions: [String: String] = [:]
        for mention in mentions {
            let key = String(mention.userNameNormalized.trimmingPrefix("@"))
            if uniqueMentions[key] == nil {
                uniqueMentions[key] = mention.userUrl ?? ""
            }
        }

        return uniqueMentions.isEmpty ? nil : uniqueMentions
    }
}

