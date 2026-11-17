//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Explicit audience and content of a new direct message. Text mentions do not grant access.
struct DirectMessageRequestDto: Content {
    var recipientIds: [String]
    var note: String
    var attachmentIds: [String]
    var replyToStatusId: String?

    init(recipientIds: [String], note: String = "", attachmentIds: [String] = [], replyToStatusId: String? = nil) {
        self.recipientIds = recipientIds
        self.note = note
        self.attachmentIds = attachmentIds
        self.replyToStatusId = replyToStatusId
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        recipientIds = try values.decode([String].self, forKey: .recipientIds)
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
        attachmentIds = try values.decodeIfPresent([String].self, forKey: .attachmentIds) ?? []
        replyToStatusId = try values.decodeIfPresent(String.self, forKey: .replyToStatusId)
    }
}
