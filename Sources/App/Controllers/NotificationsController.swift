//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

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
    }
    
    /// Exposing list of countries.
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
    
    private func getStatus(_ status: Status?, on request: Request) async -> StatusDto? {
        guard let status else {
            return nil
        }
        
        let statusesService = request.application.services.statusesService
        return await statusesService.convertToDtos(on: request, status: status, attachments: status.attachments)
    }
}