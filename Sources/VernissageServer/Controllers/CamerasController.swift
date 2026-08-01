//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import ActivityPubKit
import Fluent
import Vapor

extension CamerasController: RouteCollection {

    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("cameras")

    func boot(routes: RoutesBuilder) throws {
        let camerasGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(CamerasController.uri)
            .grouped(UserAuthenticator())

        camerasGroup
            .grouped(EventHandlerMiddleware(.camerasList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
    }
}

/// Exposing a list of cameras extracted from image EXIF metadata.
///
/// > Important: Base controller URL: `/api/v1/cameras`.
struct CamerasController {

    /// Exposing a paginable list of cameras.
    ///
    /// The cameras are sorted by the number of assigned photos, from the most
    /// frequently used camera to the least frequently used one.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    /// - `query` - filter cameras whose normalized name starts with the specified value
    ///
    /// > Important: Endpoint URL: `/api/v1/cameras`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/cameras?page=1&size=10" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "data": [{
    ///         "id": "7302167186067544065",
    ///         "name": "Sony ILCE-7M4",
    ///         "make": "Sony",
    ///         "model": "ILCE-7M4",
    ///         "amount": 42
    ///     }],
    ///     "page": 1,
    ///     "size": 10,
    ///     "total": 1
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Paginable list of cameras.
    ///
    /// - Throws: `ActionsForbiddenError.camerasForbidden` when anonymous
    ///   access to cameras is disabled.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<CameraDto> {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showCamerasForAnonymous == false {
            throw ActionsForbiddenError.camerasForbidden
        }

        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        let query: String? = request.query["query"]

        let camerasFromDatabaseQueryBuilder = Camera.query(on: request.db)

        if let query, query.isEmpty == false {
            camerasFromDatabaseQueryBuilder
                .filter(\.$nameNormalized =~ query.uppercased())
        }

        let camerasFromDatabase = try await camerasFromDatabaseQueryBuilder
            .sort(\.$amount, .descending)
            .sort(\.$name, .ascending)
            .paginate(PageRequest(page: page, per: size))

        let cameraDtos = camerasFromDatabase.items.map { CameraDto(from: $0) }

        return PaginableResultDto(
            data: cameraDtos,
            page: camerasFromDatabase.metadata.page,
            size: camerasFromDatabase.metadata.per,
            total: camerasFromDatabase.metadata.total
        )
    }
}
