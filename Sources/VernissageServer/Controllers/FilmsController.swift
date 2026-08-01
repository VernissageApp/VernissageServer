//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import ActivityPubKit
import Fluent
import Vapor

extension FilmsController: RouteCollection {

    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("films")

    func boot(routes: RoutesBuilder) throws {
        let filmsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(FilmsController.uri)
            .grouped(UserAuthenticator())

        filmsGroup
            .grouped(EventHandlerMiddleware(.filmsList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
    }
}

/// Exposing a list of films extracted from image EXIF metadata.
///
/// > Important: Base controller URL: `/api/v1/films`.
struct FilmsController {

    /// Exposing a paginable list of films.
    ///
    /// The films are sorted by the number of assigned photos, from the most
    /// frequently used film to the least frequently used one.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    /// - `query` - filter films whose normalized name starts with the specified value
    ///
    /// > Important: Endpoint URL: `/api/v1/films`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/films?page=1&size=10" \
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
    ///         "name": "Kodak Portra 400",
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
    /// - Returns: Paginable list of films.
    ///
    /// - Throws: `ActionsForbiddenError.filmsForbidden` when anonymous
    ///   access to films is disabled.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<FilmDto> {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showFilmsForAnonymous == false {
            throw ActionsForbiddenError.filmsForbidden
        }

        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        let query: String? = request.query["query"]

        let filmsFromDatabaseQueryBuilder = Film.query(on: request.db)

        if let query, query.isEmpty == false {
            filmsFromDatabaseQueryBuilder
                .filter(\.$nameNormalized =~ query.uppercased())
        }

        let filmsFromDatabase = try await filmsFromDatabaseQueryBuilder
            .sort(\.$amount, .descending)
            .sort(\.$name, .ascending)
            .paginate(PageRequest(page: page, per: size))

        let filmDtos = filmsFromDatabase.items.map { FilmDto(from: $0) }

        return PaginableResultDto(
            data: filmDtos,
            page: filmsFromDatabase.metadata.page,
            size: filmsFromDatabase.metadata.per,
            total: filmsFromDatabase.metadata.total
        )
    }
}
