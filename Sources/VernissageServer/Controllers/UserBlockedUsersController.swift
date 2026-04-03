//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension UserBlockedUsersController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("user-blocked-users")

    func boot(routes: RoutesBuilder) throws {
        let domainsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(UserBlockedUsersController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())

        domainsGroup
            .grouped(EventHandlerMiddleware(.userBlockedUsersList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
    }
}

/// Controls basic operations for user blocked users.
///
/// > Important: Base controller URL: `/api/v1/user-blocked-users`.
struct UserBlockedUsersController {

    /// List of user's blocked users.
    ///
    /// The endpoint returns a list of all user's blocked users added to the system.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/user-blocked-users`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-blocked-users" \
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
    ///             "blockedUser": { ... },
    ///             "reason": "This is a porn website.",
    ///             "createdAt": "2023-08-16T15:13:08.607Z",
    ///             "updatedAt": "2024-02-09T05:12:23.479Z"
    ///         },
    ///         {
    ///             "id": "7332804261530576897",
    ///             "blockedUser": { ... },
    ///             "reason": "Domain with spam",
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
    /// - Returns: List of paginable blocked domains.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<UserBlockedUserDto> {
        let baseImagesPath = request.application.services.storageService.getBaseImagesPath(on: request.executionContext)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let authorizationPayloadId = try request.requireUserId()
        let blockedUsersFromDatabaseQuery = UserBlockedUser.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .with(\.$blockedUser)

        let blockedUsersFromDatabase = try await blockedUsersFromDatabaseQuery
            .sort(\.$createdAt, .ascending)
            .paginate(PageRequest(page: page, per: size))
        
        let blockedUserDtos = blockedUsersFromDatabase.items.map { blockedUser in
            UserBlockedUserDto(from: blockedUser, baseImagesPath: baseImagesPath, baseAddress: baseAddress)
        }

        return PaginableResultDto(
            data: blockedUserDtos,
            page: blockedUsersFromDatabase.metadata.page,
            size: blockedUsersFromDatabase.metadata.per,
            total: blockedUsersFromDatabase.metadata.total
        )
    }
}
