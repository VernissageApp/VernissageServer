//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

final class TrendingController: RouteCollection {
    
    public static let uri: PathComponent = .constant("trending")
    
    func boot(routes: RoutesBuilder) throws {
        let timelinesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(TrendingController.uri)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.trendingStatuses))
            .get("statuses", use: statuses)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.trendingUsers))
            .get("users", use: users)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.trendingHashtags))
            .get("hashtags", use: hashtags)
    }
    
    /// Exposing trending statuses.
    func statuses(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let period: TrendingStatusPeriodDto = request.query["period"] ?? .daily
        let linkableParams = request.linkableParams()
        
        let statusesService = request.application.services.statusesService
        let trendingService = request.application.services.trendingService
        let trending = try await trendingService.statuses(on: request.db, linkableParams: linkableParams, period: period.translate())
        
        let statusDtos = await trending.data.asyncMap({
            await statusesService.convertToDtos(on: request, status: $0, attachments: $0.attachments)
        })
        
        return LinkableResultDto(
            maxId: trending.maxId,
            minId: trending.minId,
            data: statusDtos
        )
    }
    
    /// Exposing trending users.
    func users(request: Request) async throws -> LinkableResultDto<UserDto> {
        let period: TrendingStatusPeriodDto = request.query["period"] ?? .daily
        let linkableParams = request.linkableParams()
        
        let trendingService = request.application.services.trendingService
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        let trending = try await trendingService.users(on: request.db, linkableParams: linkableParams, period: period.translate())
        let userDtos = await trending.data.asyncMap({
            UserDto(from: $0, flexiFields: $0.flexiFields, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
        })
        
        return LinkableResultDto(
            maxId: trending.maxId,
            minId: trending.minId,
            data: userDtos
        )
    }
    
    /// Exposing trending hashtags.
    func hashtags(request: Request) async throws -> LinkableResultDto<HashtagDto> {
        let period: TrendingStatusPeriodDto = request.query["period"] ?? .daily
        let linkableParams = request.linkableParams()
        
        let trendingService = request.application.services.trendingService
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        let trending = try await trendingService.hashtags(on: request.db, linkableParams: linkableParams, period: period.translate())
        let hashtagDtos = await trending.data.asyncMap({
            HashtagDto(url: "\(baseAddress)/hashtag/\($0.hashtag)", name: $0.hashtag)
        })
        
        return LinkableResultDto(
            maxId: trending.maxId,
            minId: trending.minId,
            data: hashtagDtos
        )
    }
}