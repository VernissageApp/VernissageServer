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
            .grouped(EventHandlerMiddleware(.timelinesPublic))
            .get("statuses", use: statuses)
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
}
