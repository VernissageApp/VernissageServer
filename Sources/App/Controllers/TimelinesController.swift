//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

final class TimelinesController: RouteCollection {
    
    public static let uri: PathComponent = .constant("timelines")
    
    func boot(routes: RoutesBuilder) throws {
        let timelinesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(TimelinesController.uri)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.timelinesPublic))
            .get("public", use: list)
        
        timelinesGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.timelinesPublic))
            .get("home", use: home)
    }
    
    /// Exposing public timeline.
    func list(request: Request) async throws -> [String] {
        return []
    }
    
    /// Exposing home timeline.
    func home(request: Request) async throws -> [StatusDto] {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.home(on: request.db, for: authorizationPayloadId, page: 0, size: 100)
        
        return statuses.map({ self.convertToDtos(on: request, status: $0, attachments: $0.attachments) })
    }
    
    private func convertToDtos(on request: Request, status: Status, attachments: [Attachment]) -> StatusDto {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        let attachmentDtos = attachments.map({ AttachmentDto(from: $0, baseStoragePath: baseStoragePath) })
        return StatusDto(from: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath, attachments: attachmentDtos)
    }
}
