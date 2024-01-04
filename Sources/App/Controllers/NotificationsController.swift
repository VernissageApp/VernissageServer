//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

/// Controller for managing list of user's notifications.
final class NotificationsController: RouteCollection {
    
    public static let uri: PathComponent = .constant("notifications")
    
    func boot(routes: RoutesBuilder) throws {
        let notificationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(NotificationsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        notificationsGroup
            .grouped(EventHandlerMiddleware(.notificationsList))
            .get(use: list)
        
        notificationsGroup
            .grouped(EventHandlerMiddleware(.notificationsCount))
            .get("count", use: count)
        
        notificationsGroup
            .grouped(EventHandlerMiddleware(.notificationsCount))
            .post("marker", ":id", use: marker)
    }
    
    /// Exposing list of notifications.
    func list(request: Request) async throws -> LinkableResultDto<NotificationDto> {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let linkableParams = request.linkableParams()
        let notificationsService = request.application.services.notificationsService
        let notifications = try await notificationsService.list(on: request.db, for: authorizationPayloadId, linkableParams: linkableParams)
                
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let notificationDtos = await notifications.asyncMap({
            let notificationTypeDto = NotificationTypeDto.from($0.notificationType)
            let user = UserDto(from: $0.byUser, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
            let status = await self.getStatus($0.status, on: request)
            
            return NotificationDto(id: $0.stringId(), notificationType: notificationTypeDto, byUser: user, status: status)
        })
        
        return LinkableResultDto(
            maxId: notifications.last?.stringId(),
            minId: notifications.first?.stringId(),
            data: notificationDtos
        )
    }
    
    /// Amount of new notifications (since notification marker).
    func count(request: Request) async throws -> NotificationsCountDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let marker = try await NotificationMarker.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .with(\.$notification)
            .first() else {
            return NotificationsCountDto(amount: 0)
        }

        let count = try await Notification.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$id > marker.$notification.id)
            .count()
        
        return NotificationsCountDto(amount: count, notificationId: marker.notification.stringId())
    }

    /// Update notification marker..
    func marker(request: Request) async throws -> HTTPResponseStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let notificationIdString = request.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }
        
        guard let notificationId = notificationIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        guard let _ = try await Notification.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$id == notificationId)
            .first() else {
            throw Abort(.notFound)
        }
        
        if let marker = try await NotificationMarker.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .first() {
            marker.$notification.id = notificationId
            try await marker.save(on: request.db)
        } else {
            let notificationMarker = NotificationMarker(notificationId: notificationId, userId: authorizationPayloadId)
            try await notificationMarker.create(on: request.db)
        }

        return HTTPResponseStatus.ok
    }
    
    private func getStatus(_ status: Status?, on request: Request) async -> StatusDto? {
        guard let status else {
            return nil
        }
        
        let statusesService = request.application.services.statusesService
        return await statusesService.convertToDto(on: request, status: status, attachments: status.attachments)
    }
}
