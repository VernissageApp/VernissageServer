//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension ErrorItemsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("error-items")
    
    func boot(routes: RoutesBuilder) throws {
        let errorItemsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(ErrorItemsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        errorItemsGroup
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.errorList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        errorItemsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.errorCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)
        
        errorItemsGroup
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.errorDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", use: delete)
    }
}

/// Exposing list of errors.
///
/// Thanks to that controller we can save and rerturn all errors which has been
/// recorded in the system (client & server).
///
/// > Important: Base controller URL: `/api/v1/error-items`.
struct ErrorItemsController {
    
    /// Exposing list of errors.
    ///
    /// > Important: Endpoint URL: `/api/v1/error-items`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/error-items" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [{
    ///     "code": "CTcoTAfGp8",
    ///     "message": "Unexpected client error.",
    ///     "exception": "{\n  \"message\": \"This cannot be null!\"\n}",
    ///     "source": "client"
    /// }]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of errors.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<ErrorItemDto> {
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        let query: String? = request.query["query"]
        
        let errorItemsFromDatabaseQueryBuilder = ErrorItem.query(on: request.db)
        
        if let query, !query.isEmpty {
            errorItemsFromDatabaseQueryBuilder.group(.or) { group in
                group.filter(\.$code == query)
                group.filter(\.$message ~~ query)
                group.filter(\.$exception ~~ query)
            }
        }
            
        let errorItemsFromDatabase = try await errorItemsFromDatabaseQueryBuilder
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))
        
        let errorItemDtos = errorItemsFromDatabase.items.map { ErrorItemDto(from: $0) }
                        
        return PaginableResultDto(
            data: errorItemDtos,
            page: errorItemsFromDatabase.metadata.page,
            size: errorItemsFromDatabase.metadata.per,
            total: errorItemsFromDatabase.metadata.total
        )
    }
    
    /// Create new error item.
    ///
    /// The endpoint can be used for creating new error information.
    ///
    /// > Important: Endpoint URL: `/api/v1/error-items`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/error-items" \
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
    ///     "code": "CTcoTAfGp8",
    ///     "message": "Unexpected client error.",
    ///     "exception": "{\n  \"message\": \"This cannot be null!\"\n}",
    ///     "source": "client"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7428256478005299812",
    ///     "code": "CTcoTAfGp8",
    ///     "message": "Unexpected client error.",
    ///     "exception": "{\n  \"message\": \"This cannot be null!\"\n}",
    ///     "source": "client",
    ///     "createdAt": "2024-10-21T15:48:57.455Z",
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: New added entity.
    @Sendable
    func create(request: Request) async throws -> Response {
        try ErrorItemDto.validate(content: request)

        let errorItemDto = try request.content.decode(ErrorItemDto.self)
        let userAgent = request.headers[.userAgent].first

        let id = request.application.services.snowflakeService.generate()
        let errorItem = ErrorItem(id: id,
                                  source: errorItemDto.source.translate(),
                                  code: errorItemDto.code,
                                  message: errorItemDto.message,
                                  exception: errorItemDto.exception,
                                  userAgent: userAgent,
                                  clientVersion: errorItemDto.clientVersion,
                                  serverVersion: Constants.version)

        try await errorItem.save(on: request.db)
        return try await createNewErrorItemResponse(on: request, errorItem: errorItem)
    }
    
    /// Delete error from the database.
    ///
    /// The endpoint can be used for deleting existing error.
    ///
    /// > Important: Endpoint URL: `/api/v1/error-items/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/error-items/7267938074834522113" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Http status code.
    @Sendable
    func delete(request: Request) async throws -> HTTPStatus {
        guard let errorItemIdString = request.parameters.get("id", as: String.self) else {
            throw ErrorItemError.incorrectErrorItemId
        }
        
        guard let errorItemId = errorItemIdString.toId() else {
            throw ErrorItemError.incorrectErrorItemId
        }
        
        guard let errorItem = try await ErrorItem.find(errorItemId, on: request.db) else {
            throw EntityNotFoundError.errorItemNotFound
        }
        
        try await errorItem.delete(on: request.db)
        return HTTPStatus.ok
    }
    
    private func createNewErrorItemResponse(on request: Request, errorItem: ErrorItem) async throws -> Response {
        let errorItemDto = ErrorItemDto(from: errorItem)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(ErrorItemsController.uri)/\(errorItem.stringId() ?? "")")
        
        return try await errorItemDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
