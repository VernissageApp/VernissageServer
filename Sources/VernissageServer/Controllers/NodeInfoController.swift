//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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
            .get("2.0", use: nodeinfo2)
    }
}

/// Controller implements NodeInfo protocol.
final class NodeInfoController {
        
    /// Exposing NodeInfo data.
    ///
    /// [NodeInfo](http://nodeinfo.diaspora.software) is an effort to create a standardized way of exposing metadata
    /// about a server running one of the distributed social networks. The two key goals are being able to get better insights into the
    /// user base of distributed social networking and the ability to build tools that allow users to choose the best fitting software and
    /// server for their needs.
    /// More info: [https://github.com/jhass/nodeinfo](https://github.com/jhass/nodeinfo).
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
