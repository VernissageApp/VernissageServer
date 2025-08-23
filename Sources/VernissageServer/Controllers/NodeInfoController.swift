//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

extension NodeInfoController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("nodeinfo")
    
    func boot(routes: RoutesBuilder) throws {
        let webfingerGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(NodeInfoController.uri)
        
        webfingerGroup
            .grouped(EventHandlerMiddleware(.webfinger))
            .grouped(CacheControlMiddleware(.public()))
            .get("2.0", use: nodeinfo2)
    }
}

/// Controller implements NodeInfo protocol.
///
/// NodeInfo is a simple protocol used by Mastodon and other federated social networking software. It provides basic information
/// about a server (or "node") in a federated network, such as its software version, uptime, and supported features.
/// NodeInfo protocol allows servers in a federated network to communicate with each other more efficiently.
///
/// > Important: Base controller URL: `/api/v1/nodeinfo`.
struct NodeInfoController {
        
    /// Exposing NodeInfo data.
    ///
    /// [NodeInfo](http://nodeinfo.diaspora.software) is an effort to create a standardized way of exposing metadata
    /// about a server running one of the distributed social networks. The two key goals are being able to get better insights into the
    /// user base of distributed social networking and the ability to build tools that allow users to choose the best fitting software and
    /// server for their needs.
    /// More info: [https://github.com/jhass/nodeinfo](https://github.com/jhass/nodeinfo).
    ///
    /// > Important: Endpoint URL: `/api/v1/nodeinfo`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/nodeinfo" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "openRegistrations": true,
    ///     "services": {
    ///         "inbound": [],
    ///         "outbound": []
    ///     },
    ///     "protocols": [
    ///         "activitypub"
    ///     ],
    ///     "software": {
    ///         "name": "Vernissage",
    ///         "version": "1.0"
    ///     },
    ///     "usage": {
    ///         "users": {
    ///             "total": 2,
    ///             "activeMonth": 2,
    ///             "activeHalfyear": 2
    ///         },
    ///         "localComments": 0,
    ///         "localPosts": 0
    ///     },
    ///     "metadata": {
    ///         "nodeName": "localhost"
    ///     },
    ///     "version": "2.0"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: NodeInfo information.
    @Sendable
    func nodeinfo2(request: Request) async throws -> NodeInfoDto {
        let nodeInfoCacheKey = String(describing: NodeInfoDto.self)

        if let nodeInfoFromCache: NodeInfoDto = try? await request.cache.get(nodeInfoCacheKey) {
            return nodeInfoFromCache
        }
        
        let applicationSettings = request.application.settings.cached
        let isRegistrationOpened = applicationSettings?.isRegistrationOpened ?? false
        let nodeName = applicationSettings?.webTitle ?? "unkonwn"
        let nodeDescription = applicationSettings?.webDescription ?? "unkonwn"
        
        let usersService = request.application.services.usersService
        let totalUsers =  try await usersService.count(sinceLastLoginDate: nil, on: request.db)
        let activeMonth =  try await usersService.count(sinceLastLoginDate: Date.monthAgo, on: request.db)
        let activeHalfyear = try await usersService.count(sinceLastLoginDate: Date.halfYearAgo, on: request.db)
        
        let statusesService = request.application.services.statusesService
        let localPosts = try await statusesService.count(onlyComments: false, on: request.db)
        let localComments = try await statusesService.count(onlyComments: true, on: request.db)
        
        let nodeInfoDto = NodeInfoDto(version: "2.0",
                                      openRegistrations: isRegistrationOpened,
                                      software: NodeInfoSoftwareDto(name: Constants.name, version: Constants.version),
                                      protocols: ["activitypub"],
                                      services: NodeInfoServicesDto(outbound: [], inbound: []),
                                      usage: NodeInfoUsageDto(users: NodeInfoUsageUsersDto(total: totalUsers,
                                                                                           activeMonth: activeMonth,
                                                                                           activeHalfyear: activeHalfyear),
                                                              localPosts: localPosts,
                                                              localComments: localComments),
                                      metadata: NodeInfoMetadataDto(nodeName: nodeName,
                                                                    nodeDescription: nodeDescription))
        
        try? await request.cache.set(nodeInfoCacheKey, to: nodeInfoDto, expiresIn: .minutes(10))
        return nodeInfoDto
    }
}
