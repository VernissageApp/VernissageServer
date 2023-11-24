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
            .grouped(EventHandlerMiddleware(.timelinesPublic))
            .get("hashtag", ":hashtag", use: hashtag)
        
        timelinesGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.timelinesPublic))
            .get("home", use: home)
    }
    
    /// Exposing public timeline.
    func list(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let onlyLocal: Bool = request.query["onlyLocal"] ?? false
        let linkableParams = request.linkableParams()
        
        let statusesService = request.application.services.statusesService
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.public(on: request.db, linkableParams: linkableParams, onlyLocal: onlyLocal)
        
        let statusDtos = await statuses.asyncMap({
            await statusesService.convertToDtos(on: request, status: $0, attachments: $0.attachments)
        })
        
        return LinkableResultDto(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statusDtos
        )
    }
    
    /// Exposing public hashtag timeline.
    func hashtag(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let onlyLocal: Bool = request.query["onlyLocal"] ?? false
        let linkableParams = request.linkableParams()
        
        guard let hashtag = request.parameters.get("hashtag") else {
            throw Abort(.badRequest)
        }
        
        let statusesService = request.application.services.statusesService
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.hashtags(on: request.db, linkableParams: linkableParams, hashtag: hashtag, onlyLocal: onlyLocal)
        
        let statusDtos = await statuses.asyncMap({
            await statusesService.convertToDtos(on: request, status: $0, attachments: $0.attachments)
        })
        
        return LinkableResultDto(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statusDtos
        )
    }
    
    /// Exposing home timeline.
    func home(request: Request) async throws -> LinkableResultDto<StatusDto> {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        let linkableParams = request.linkableParams()
        let statusesService = request.application.services.statusesService
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.home(on: request.db, for: authorizationPayloadId, linkableParams: linkableParams)
        
        let statusDtos = await statuses.asyncMap({
            await statusesService.convertToDtos(on: request, status: $0, attachments: $0.attachments)
        })
        
        return LinkableResultDto(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statusDtos
        )
    }
}
