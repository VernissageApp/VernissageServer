//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension HomeCardsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("home-cards")
    
    func boot(routes: RoutesBuilder) throws {
        let locationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(HomeCardsController.uri)
        
        locationsGroup
            .grouped(EventHandlerMiddleware(.homeCardsCachedList))
            .grouped(CacheControlMiddleware(.public()))
            .get("cached", use: list)
        
        locationsGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.homeCardsList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        locationsGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.homeCardsCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)

        locationsGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.homeCardsUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .put(":id", use: update)
        
        locationsGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.homeCardsDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", use: delete)
    }
}

/// Exposing list of home cards.
///
/// On the public home page we can show specific features or other
/// information for the people. Each instance can have diferent features
/// which should be displayed.
///
/// > Important: Base controller URL: `/api/v1/home-cards`.
struct HomeCardsController {
        
    /// Exposing list of home cards..
    ///
    /// An endpoint that returns a list of home cards added to the system.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/home-cards`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/home-cards" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "data": [{
    ///         "title": "First home card",
    ///         "body": "This is very important feature.",
    ///         "id": "7310961711425626113",
    ///         "order": 1
    ///     }, {
    ///         "title": "Second home card",
    ///         "body": "Second very important feature.",
    ///         "id": "7310961711425757185",
    ///         "order": 2
    ///     }],
    ///     "page": 1,
    ///     "size": 2,
    ///     "total": 13
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of paginable home cards.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<HomeCardDto> {
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let homeCardsFromDatabase = try await HomeCard.query(on: request.db)
            .sort(\.$order, .ascending)
            .paginate(PageRequest(page: page, per: size))
        
        let homeCardsDtos = homeCardsFromDatabase.items.map { homeCard in
            HomeCardDto(from: homeCard)
        }

        return PaginableResultDto(
            data: homeCardsDtos,
            page: homeCardsFromDatabase.metadata.page,
            size: homeCardsFromDatabase.metadata.per,
            total: homeCardsFromDatabase.metadata.total
        )
    }
    
    /// Create new home card.
    ///
    /// The endpoint can be used for creating new home card.
    ///
    /// > Important: Endpoint URL: `/api/v1/home-cards`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/home-cards" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "title": "First home card",
    ///     "body": "This is very important feature.",
    ///     "order": 1
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "title": "First home card",
    ///     "body": "This is very important feature.",
    ///     "id": "7310961711425626113",
    ///     "order": 1
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: New added entity.
    @Sendable
    func create(request: Request) async throws -> Response {
        let homeCardDto = try request.content.decode(HomeCardDto.self)
        try HomeCardDto.validate(content: request)
        
        let id = request.application.services.snowflakeService.generate()
        let homeCard = HomeCard(id: id, title: homeCardDto.title, body: homeCardDto.body, order: homeCardDto.order)

        try await homeCard.save(on: request.db)
        return try await createNewHomeCardResponse(on: request, homeCard: homeCard)
    }
    
    /// Update home card in the database.
    ///
    /// The endpoint can be used for updating existing home card.
    ///
    /// > Important: Endpoint URL: `/api/v1/home-cards/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/home-cards/7310961711425757185" \
    /// -X PUT \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "id": "7310961711425757185",
    ///     "title": "First home card (updated)",
    ///     "body": "This is very important feature.",
    ///     "order": 1
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7310961711425757185",
    ///     "title": "First home card (updated)",
    ///     "body": "This is very important feature.",
    ///     "order": 1
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Updated entity.
    ///
    /// - Throws: `HomeCardError.incorrectHomeCardId` if home card id is incorrect.
    /// - Throws: `EntityNotFoundError.homeCardNotFound` if home card not exists.
    @Sendable
    func update(request: Request) async throws -> HomeCardDto {
        let homeCardDto = try request.content.decode(HomeCardDto.self)
        try HomeCardDto.validate(content: request)
        
        guard let homeCardIdString = request.parameters.get("id", as: String.self) else {
            throw HomeCardError.incorrectHomeCardId
        }
        
        guard let homeCardId = homeCardIdString.toId() else {
            throw HomeCardError.incorrectHomeCardId
        }
        
        guard let homeCard = try await HomeCard.find(homeCardId, on: request.db) else {
            throw EntityNotFoundError.homeCardNotFound
        }
        
        homeCard.title = homeCardDto.title
        homeCard.body = homeCardDto.body
        homeCard.order = homeCardDto.order

        try await homeCard.save(on: request.db)
        return HomeCardDto(from: homeCard)
    }
    
    /// Delete home card from the database.
    ///
    /// The endpoint can be used for deleting existing home card.
    ///
    /// > Important: Endpoint URL: `/api/v1/home-cards/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/home-cards/7310961711425757185" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Http status code.
    ///
    /// - Throws: `HomeCardError.incorrectHomeCardId` if home card id is incorrect.
    /// - Throws: `EntityNotFoundError.homeCardNotFound` if home card not exists.
    @Sendable
    func delete(request: Request) async throws -> HTTPStatus {
        guard let homeCardIdString = request.parameters.get("id", as: String.self) else {
            throw HomeCardError.incorrectHomeCardId
        }
        
        guard let homeCardId = homeCardIdString.toId() else {
            throw HomeCardError.incorrectHomeCardId
        }
        
        guard let homeCard = try await HomeCard.find(homeCardId, on: request.db) else {
            throw EntityNotFoundError.homeCardNotFound
        }
        
        try await homeCard.delete(on: request.db)
        return HTTPStatus.ok
    }
    
    private func createNewHomeCardResponse(on request: Request, homeCard: HomeCard) async throws -> Response {
        let homeCardDto = HomeCardDto(from: homeCard)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(HomeCardsController.uri)/\(homeCard.stringId() ?? "")")
        
        return try await homeCardDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
