//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Information about single ActivityPub events connected with status.
final class StatusActivityPubEvent: Model, @unchecked Sendable {
    static let schema: String = "StatusActivityPubEvents"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "statusId")
    var status: Status

    @Parent(key: "userId")
    var user: User
    
    @Field(key: "type")
    var type: ActivityTypeDto

    @Field(key: "result")
    var result: StatusActivityPubEventResult
    
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

    @Children(for: \.$statusActivityPubEvent)
    var statusActivityPubEventItems: [StatusActivityPubEventItem]
    
    init() { }

    convenience init(id: Int64, statusId: Int64, userId: Int64, type: ActivityTypeDto) {
        self.init()

        self.id = id
        self.$status.id = statusId
        self.$user.id = userId
        self.type = type
        self.result = .waiting
    }
}

/// Allows `StatusActivityPubEvent` to be encoded to and decoded from HTTP messages.
extension StatusActivityPubEvent: Content { }

extension StatusActivityPubEvent {
    func error(_ errorMessage: String) {
        self.endAt = Date()
        self.result = .failed
        self.errorMessage = errorMessage
    }
    
    func success(result: StatusActivityPubEventResult) {
        self.endAt = Date()
        self.result = result
    }
}
