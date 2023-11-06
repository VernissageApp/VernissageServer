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
    func list(request: Request) async throws -> [NotificationDto] {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let minId: String? = request.query["minId"]
        let maxId: String? = request.query["maxId"]
        let sinceId: String? = request.query["sinceId"]
        let limit: Int = request.query["limit"] ?? 40
        
        
        let notificationsService = request.application.services.notificationsService
        let notifications = try await notificationsService.list(on: request.db,
                                                      for: authorizationPayloadId,
                                                      minId: minId,
                                                      maxId: maxId,
                                                      sinceId: sinceId,
                                                      limit: limit)
                
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        return await notifications.asyncMap({
            let notificationTypeDto = NotificationTypeDto.from($0.notificationType)
            let user = UserDto(from: $0.byUser, flexiFields: [], baseStoragePath: baseStoragePath, baseAddress: baseAddress)
            let status = await self.getStatus($0.status, on: request)
            
            return NotificationDto(notificationType: notificationTypeDto, byUser: user, status: status)
        })
    }
    
    private func getStatus(_ status: Status?, on request: Request) async -> StatusDto? {
        guard let status else {
            return nil
        }
        
        let statusesService = request.application.services.statusesService
        return await statusesService.convertToDtos(on: request, status: status, attachments: status.attachments)
    }
}
