//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import ActivityPubKit
import Fluent
import Vapor

extension LensesController: RouteCollection {

    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("lenses")

    func boot(routes: RoutesBuilder) throws {
        let lensesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(LensesController.uri)
            .grouped(UserAuthenticator())

        lensesGroup
            .grouped(EventHandlerMiddleware(.lensesList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
    }
}

/// Exposing a list of lenses extracted from image EXIF metadata.
///
/// > Important: Base controller URL: `/api/v1/lenses`.
struct LensesController {

    /// Exposing a paginable list of lenses.
    ///
    /// The lenses are sorted by the number of assigned photos, from the most
    /// frequently used lens to the least frequently used one.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    /// - `query` - filter lenses whose normalized name starts with the specified value
    ///
    /// > Important: Endpoint URL: `/api/v1/lenses`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/lenses?page=1&size=10" \
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
    ///         "name": "Viltrox 85mm",
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
    /// - Returns: Paginable list of lenses.
    ///
    /// - Throws: `ActionsForbiddenError.lensesForbidden` when anonymous
    ///   access to lenses is disabled.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<LensDto> {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showLensesForAnonymous == false {
            throw ActionsForbiddenError.lensesForbidden
        }

        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        let query: String? = request.query["query"]

        let lensesFromDatabaseQueryBuilder = Lens.query(on: request.db)

        if let query, query.isEmpty == false {
            lensesFromDatabaseQueryBuilder
                .filter(\.$nameNormalized =~ query.uppercased())
        }

        let lensesFromDatabase = try await lensesFromDatabaseQueryBuilder
            .sort(\.$amount, .descending)
            .sort(\.$name, .ascending)
            .paginate(PageRequest(page: page, per: size))

        let lensDtos = lensesFromDatabase.items.map { LensDto(from: $0) }

        return PaginableResultDto(
            data: lensDtos,
            page: lensesFromDatabase.metadata.page,
            size: lensesFromDatabase.metadata.per,
            total: lensesFromDatabase.metadata.total
        )
    }
}
