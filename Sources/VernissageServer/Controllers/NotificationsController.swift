//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension NotificationsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("notifications")
    
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
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.notificationsCount))
            .post("marker", ":id", use: marker)
    }
}

/// Controller for managing list of user's notifications.
///
/// Controller, which is used to manage user notifications. With it, you can retrieve a list of notifications,
/// the number of unread notifications (which can be used for client-side display), and mark
/// the notification last seen by the user.
///
/// > Important: Base controller URL: `/api/v1/notifications`.
struct NotificationsController {
    
    /// Exposing list of notifications.
    ///
    /// An endpoint that returns a list of notifications intended for the user.
    /// The list shows notifications such as new likes, reports, follows, etc.
    ///
    /// Optional query params:
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/notifications`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/notifications" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "data": [
    ///         {
    ///             "byUser": { ... },
    ///             "id": "7310891166589564929",
    ///             "notificationType": "favourite",
    ///             "status": { ... }
    ///         }
    ///     ],
    ///     "maxId": "7304731590779914241",
    ///     "minId": "7310891166589564929"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable notifications.
    @Sendable
    func list(request: Request) async throws -> LinkableResultDto<NotificationDto> {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let linkableParams = request.linkableParams()
        let notificationsService = request.application.services.notificationsService
        let usersService = request.application.services.usersService
        
        let notifications = try await notificationsService.list(for: authorizationPayloadId, linkableParams: linkableParams, on: request.db)

        let notificationDtos = await notifications.asyncMap({
            let notificationTypeDto = NotificationTypeDto.from($0.notificationType)
            
            let user = await usersService.convertToDto(user: $0.byUser,
                                                       flexiFields: $0.byUser.flexiFields,
                                                       roles: nil,
                                                       attachSensitive: false,
                                                       on: request.executionContext)

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
    ///
    /// An endpoint that returns information about the number of new notifications
    /// that the user has not yet had a chance to see.
    ///
    /// > Important: Endpoint URL: `/api/v1/notifications/count`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/notifications/count" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "amount": 4,
    ///     "notificationId": "7310891166589564929"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about new (not readed) notifications.
    @Sendable
    func count(request: Request) async throws -> NotificationsCountDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        let notificationsService = request.application.services.notificationsService
        let (count, marker) = try await notificationsService.count(for: authorizationPayloadId, on: request.db)
        
        return NotificationsCountDto(amount: count, notificationId: marker?.notification.stringId())
    }

    /// Update notification marker.
    ///
    /// The endpoint through which the last notification read by the user is marked.
    ///
    /// > Important: Endpoint URL: `/api/v1/notifications/marker/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/notifications/marker/7310891166589564929" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    @Sendable
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
            let id = request.application.services.snowflakeService.generate()
            let notificationMarker = NotificationMarker(id: id, notificationId: notificationId, userId: authorizationPayloadId)
            try await notificationMarker.create(on: request.db)
        }

        return HTTPResponseStatus.ok
    }
    
    private func getStatus(_ status: Status?, on request: Request) async -> StatusDto? {
        guard let status else {
            return nil
        }
        
        let statusesService = request.application.services.statusesService
        return await statusesService.convertToDto(status: status, attachments: status.attachments, on: request.executionContext)
    }
}
