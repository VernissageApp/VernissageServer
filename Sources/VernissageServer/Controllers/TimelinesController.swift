//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension TimelinesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("timelines")
    
    func boot(routes: RoutesBuilder) throws {
        let timelinesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(TimelinesController.uri)
            .grouped(UserAuthenticator())
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.timelinesPublic))
            .get("public", use: list)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.timelinesCategories))
            .get("category", ":category", use: category)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.timelinesHashtags))
            .get("hashtag", ":hashtag", use: hashtag)

        timelinesGroup
            .grouped(EventHandlerMiddleware(.timelinesFeatured))
            .get("featured", use: featured)
        
        timelinesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.timelinesPublic))
            .get("home", use: home)
    }
}

/// Returns user's timelines.
final class TimelinesController {
        
    /// Exposing public timeline.
    func list(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let onlyLocal: Bool = request.query["onlyLocal"] ?? false
        let linkableParams = request.linkableParams()
                
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.public(on: request.db, linkableParams: linkableParams, onlyLocal: onlyLocal)
        
        let statusesService = request.application.services.statusesService
        let statusDtos = await statusesService.convertToDtos(on: request, statuses: statuses)
        
        return LinkableResultDto(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statusDtos
        )
    }
    
    /// Exposing public category timeline.
    func category(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let onlyLocal: Bool = request.query["onlyLocal"] ?? false
        let linkableParams = request.linkableParams()
        
        guard let categoryName = request.parameters.get("category") else {
            throw Abort(.badRequest)
        }
        
        guard let category = try await Category.query(on: request.db)
            .filter(\.$nameNormalized == categoryName.uppercased())
            .first() else {
            throw Abort(.notFound)
        }
        
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.category(on: request.db, linkableParams: linkableParams, categoryId: category.requireID(), onlyLocal: onlyLocal)
        
        let statusesService = request.application.services.statusesService
        let statusDtos = await statusesService.convertToDtos(on: request, statuses: statuses)
        
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
        
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.hashtags(on: request.db, linkableParams: linkableParams, hashtag: hashtag, onlyLocal: onlyLocal)
        
        let statusesService = request.application.services.statusesService
        let statusDtos = await statusesService.convertToDtos(on: request, statuses: statuses)
        
        return LinkableResultDto(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statusDtos
        )
    }
    
    /// Exposing public featured timeline.
    func featured(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let onlyLocal: Bool = request.query["onlyLocal"] ?? false
        let linkableParams = request.linkableParams()
                
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.featured(on: request.db, linkableParams: linkableParams, onlyLocal: onlyLocal)
        
        let statusesService = request.application.services.statusesService
        let statusDtos = await statusesService.convertToDtos(on: request, statuses: statuses.data)
        
        return LinkableResultDto(
            maxId: statuses.maxId,
            minId: statuses.minId,
            data: statusDtos
        )
    }
    
    /// Exposing home timeline.
    func home(request: Request) async throws -> LinkableResultDto<StatusDto> {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        let linkableParams = request.linkableParams()
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.home(on: request.db, for: authorizationPayloadId, linkableParams: linkableParams)
        
        let statusesService = request.application.services.statusesService
        let statusDtos = await statusesService.convertToDtos(on: request, statuses: statuses.data)
        
        return LinkableResultDto(
            maxId: statuses.maxId,
            minId: statuses.minId,
            data: statusDtos
        )
    }
}
