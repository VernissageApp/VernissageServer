//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension UserMutesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("user-mutes")

    func boot(routes: RoutesBuilder) throws {
        let domainsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(UserMutesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())

        domainsGroup
            .grouped(EventHandlerMiddleware(.userMutesList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
    }
}

/// Controls basic operations for user mutes.
///
/// With this controller, the user can manage users which he muted.
///
/// > Important: Base controller URL: `/api/v1/user-mutes`.
struct UserMutesController {

    /// List of muted users.
    ///
    /// The endpoint returns a list of all users muted by the user..
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/user-mutes`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-mutes" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "data": [
    ///         {
    ///             "id": "7267938074834522113",
    ///             "mutedUser": { ... },
    ///             "muteStatuses": true,
    ///             "muteReblogs": true,
    ///             "muteNotifications": true,
    ///             "muteEnd": "2028-05-13T00:00:00.000Z",
    ///             "createdAt": "2023-08-16T15:13:08.607Z",
    ///             "updatedAt": "2024-02-09T05:12:23.479Z"
    ///         },
    ///         {
    ///             "id": "7332804261530576897",
    ///             "mutedUser": { ... },
    ///             "muteStatuses": true,
    ///             "muteReblogs": true,
    ///             "muteNotifications": true,
    ///             "muteEnd": "2028-05-13T00:00:00.000Z",
    ///             "createdAt": "2024-02-07T10:25:36.538Z",
    ///             "updatedAt": "2024-02-07T10:25:36.538Z"
    ///         }
    ///     ],
    ///     "page": 1,
    ///     "size": 2,
    ///     "total": 176
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of paginable muted users.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<UserMuteDto> {
        let baseImagesPath = request.application.services.storageService.getBaseImagesPath(on: request.executionContext)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let authorizationPayloadId = try request.requireUserId()
        let userMutesFromDatbaseQuery = UserMute.query(on: request.db)
            .with(\.$mutedUser)
            .filter(\.$user.$id == authorizationPayloadId)
        
        let userMutesFromDatabase = try await userMutesFromDatbaseQuery
            .sort(\.$createdAt, .ascending)
            .paginate(PageRequest(page: page, per: size))
        
        let userMutesDtos = userMutesFromDatabase.items.map { userMute in
            UserMuteDto(from: userMute, baseImagesPath: baseImagesPath, baseAddress: baseAddress)
        }

        return PaginableResultDto(
            data: userMutesDtos,
            page: userMutesFromDatabase.metadata.page,
            size: userMutesFromDatabase.metadata.per,
            total: userMutesFromDatabase.metadata.total
        )
    }
}
