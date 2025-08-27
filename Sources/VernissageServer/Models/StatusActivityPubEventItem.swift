//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Information about single ActivityPub message connected with status.
final class StatusActivityPubEventItem: Model, @unchecked Sendable {
    static let schema: String = "StatusActivityPubEventItems"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "statusActivityPubEventId")
    var statusActivityPubEvent: StatusActivityPubEvent

    @Field(key: "url")
    var url: String

    @Field(key: "isSuccess")
    var isSuccess: Bool?
    
    @Field(key: "errorMessage")
    var errorMessage: String?
    
    @Timestamp(key: "startAt", on: .none)
    var startAt: Date?
    
    @Timestamp(key: "endAt", on: .none)
    var endAt: Date?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, statusActivityPubEventId: Int64, url: String) {
        self.init()

        self.id = id
        self.$statusActivityPubEvent.id = statusActivityPubEventId
        self.url = url
    }
}

/// Allows `StatusActivityPubEventItem` to be encoded to and decoded from HTTP messages.
extension StatusActivityPubEventItem: Content { }

extension StatusActivityPubEventItem {
    func error(_ errorMessage: String) {
        self.endAt = Date()
        self.isSuccess = false
        self.errorMessage = errorMessage
    }
    
    func success() {
        self.endAt = Date()
        self.isSuccess = true
    }
}
