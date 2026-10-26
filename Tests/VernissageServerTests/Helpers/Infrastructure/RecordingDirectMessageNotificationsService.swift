//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Vapor

/// Delegates persistence to the real service and records dispatch instead of contacting a push provider.
struct RecordingDirectMessageNotificationsService: NotificationsServiceType {
    let base: any NotificationsServiceType
    let recorder: DirectMessageNotificationRecorder
    var failAfterSave = false

    func create(type: NotificationType, to user: User, by byUserId: Int64, statusId: Int64?, mainStatusId: Int64?, on context: ExecutionContext) async throws {
        try await base.create(type: type, to: user, by: byUserId, statusId: statusId, mainStatusId: mainStatusId, on: context)
    }

    func createStored(type: NotificationType, to user: User, by byUserId: Int64, statusId: Int64?, mainStatusId: Int64?, on context: ExecutionContext) async throws -> VernissageServer.Notification? {
        let notification = try await base.createStored(type: type, to: user, by: byUserId,
                                                      statusId: statusId, mainStatusId: mainStatusId, on: context)
        await recorder.saved(inTransaction: context.db.inTransaction)

        if failAfterSave {
            throw Abort(.internalServerError)
        }

        return notification
    }

    func sendWebPushes(for notifications: [VernissageServer.Notification], on context: ExecutionContext) async throws {
        if notifications.isEmpty == false {
            await recorder.dispatched(inTransaction: context.db.inTransaction)
        }
    }

    func delete(type: NotificationType, to userId: Int64, by byUserId: Int64, statusId: Int64, on database: Database) async throws {
        try await base.delete(type: type, to: userId, by: byUserId, statusId: statusId, on: database)
    }

    func list(for userId: Int64, linkableParams: LinkableParams, on database: Database) async throws -> [VernissageServer.Notification] {
        try await base.list(for: userId, linkableParams: linkableParams, on: database)
    }

    func count(for userId: Int64, on database: Database) async throws -> (count: Int, marker: NotificationMarker?) {
        try await base.count(for: userId, on: database)
    }
}
