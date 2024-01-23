//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

/// Controller implements NodeInfo protocol: https://github.com/jhass/nodeinfo.
final class NodeInfoController: RouteCollection {
    
    public static let uri: PathComponent = .constant("nodeinfo")
    
    func boot(routes: RoutesBuilder) throws {
        let webfingerGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(NodeInfoController.uri)
        
        webfingerGroup
            .grouped(EventHandlerMiddleware(.webfinger))
            .get("2.0", use: nodeinfo2)
    }
    
    /// Exposing NodeInfo data.
    func nodeinfo2(request: Request) async throws -> NodeInfoDto {
        let appplicationSettings = request.application.settings.cached
        let isRegistrationOpened = appplicationSettings?.isRegistrationOpened ?? false
        let baseAddress = appplicationSettings?.baseAddress ?? "http://localhost"
        let nodeName = URL(string: baseAddress)?.host ?? "unkonwn"
        
        let usersService = request.application.services.usersService
        let totalUsers =  try await usersService.count(on: request.db, sinceLastLoginDate: nil)
        let activeMonth =  try await usersService.count(on: request.db, sinceLastLoginDate: Date.monthAgo)
        let activeHalfyear = try await usersService.count(on: request.db, sinceLastLoginDate: Date.halfYearAgo)
        
        let statusesService = request.application.services.statusesService
        let localPosts = try await statusesService.count(on: request.db, onlyComments: false)
        let localComments = try await statusesService.count(on: request.db, onlyComments: true)
        
        return NodeInfoDto(version: "2.0",
                           openRegistrations: isRegistrationOpened,
                           software: NodeInfoSoftwareDto(name: Constants.name, version: Constants.version),
                           protocols: ["activitypub"],
                           services: NodeInfoServicesDto(outbound: [], inbound: []),
                           usage: NodeInfoUsageDto(users: NodeInfoUsageUsersDto(total: totalUsers,
                                                                                activeMonth: activeMonth,
                                                                                activeHalfyear: activeHalfyear),
                                                   localPosts: localPosts,
                                                   localComments: localComments),
                           metadata: NodeInfoMetadataDto(nodeName: nodeName))
    }
}
