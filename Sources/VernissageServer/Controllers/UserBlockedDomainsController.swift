//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension UserBlockedDomainsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("user-blocked-domains")

    func boot(routes: RoutesBuilder) throws {
        let domainsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(UserBlockedDomainsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())

        domainsGroup
            .grouped(EventHandlerMiddleware(.userBlockedDomainsList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        domainsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.userBlockedDomainsCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)

        domainsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.userBlockedDomainsUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .put(":id", use: update)
        
        domainsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.userBlockedDomainsDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", use: delete)
    }
}

/// Controls basic operations for user blocked domains.
///
/// With this controller, the user can manage his blocked domains.
///
/// > Important: Base controller URL: `/api/v1/user-blocked-domains`.
struct UserBlockedDomainsController {

    /// List of user's blocked domains.
    ///
    /// The endpoint returns a list of all user's blocked domains added to the system.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/user-blocked-domains`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-blocked-domains" \
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
    ///             "domain": "pornsix.com",
    ///             "reason": "This is a porn website.",
    ///             "createdAt": "2023-08-16T15:13:08.607Z",
    ///             "updatedAt": "2024-02-09T05:12:23.479Z"
    ///         },
    ///         {
    ///             "id": "7332804261530576897",
    ///             "domain": "spamix.com",
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
    func list(request: Request) async throws -> PaginableResultDto<UserBlockedDomainDto> {
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let domainsFromDatabase = try await UserBlockedDomain.query(on: request.db)
            .sort(\.$domain, .ascending)
            .paginate(PageRequest(page: page, per: size))
        
        let domainsDtos = domainsFromDatabase.items.map { domain in
            UserBlockedDomainDto(from: domain)
        }

        return PaginableResultDto(
            data: domainsDtos,
            page: domainsFromDatabase.metadata.page,
            size: domainsFromDatabase.metadata.per,
            total: domainsFromDatabase.metadata.total
        )
    }
    
    /// Create new user's blocked domain.
    ///
    /// The endpoint can be used for creating new user's blocked domains.
    ///
    /// > Important: Endpoint URL: `/api/v1/user-blocked-domains`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-blocked-domains" \
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
    ///     "domain": "pornsix.com",
    ///     "reason": "This is a porn website."
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7267938074834522113",
    ///     "domain": "pornsix.com",
    ///     "reason": "This is a porn website.",
    ///     "createdAt": "2023-08-16T15:13:08.607Z",
    ///     "updatedAt": "2024-02-09T05:12:23.479Z"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: New added entity.
    @Sendable
    func create(request: Request) async throws -> Response {
        let userBlockedDomainDto = try request.content.decode(UserBlockedDomainDto.self)
        try UserBlockedDomainDto.validate(content: request)
        let authorizationPayloadId = try request.requireUserId()
        
        let id = request.application.services.snowflakeService.generate()
        let userBlockedDomain = UserBlockedDomain(id: id,
                                                  userId: authorizationPayloadId,
                                                  domain: userBlockedDomainDto.domain,
                                                  reason: userBlockedDomainDto.reason)

        try await userBlockedDomain.save(on: request.db)
        return try await createNewUserBlockedDomainResponse(on: request, userBlockedDomain: userBlockedDomain)
    }
    
    /// Update user's blocked domain in the database.
    ///
    /// The endpoint can be used for updating existing user's blocked domain.
    ///
    /// > Important: Endpoint URL: `/api/v1/user-blocked-domains/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-blocked-domains/7267938074834522113" \
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
    ///     "id": "7267938074834522113",
    ///     "domain": "pornsix2.com",
    ///     "reason": "This is a new porn website."
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7267938074834522113",
    ///     "domain": "pornsix2.com",
    ///     "reason": "This is a new porn website.",
    ///     "createdAt": "2023-08-16T15:13:08.607Z",
    ///     "updatedAt": "2024-02-09T05:12:23.479Z"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Updated entity.
    ///
    /// - Throws: `UserBlockedDomainError.incorrectId` if incorrect id is specified.
    /// - Throws: `EntityNotFoundError.userBlockedDomainNotFound` if user's blocked domain not found.
    /// - Throws: `EntityForbiddenError.userDomainBlockedForbidden` if user cannot access specific user's blocked domain.
    @Sendable
    func update(request: Request) async throws -> UserBlockedDomainDto {
        let userBlockedDomainDto = try request.content.decode(UserBlockedDomainDto.self)
        try UserBlockedDomainDto.validate(content: request)
        
        guard let domainIdString = request.parameters.get("id", as: String.self) else {
            throw UserBlockedDomainError.incorrectId
        }
        
        guard let domainId = domainIdString.toId() else {
            throw UserBlockedDomainError.incorrectId
        }
        
        guard let userBlockedDomain = try await UserBlockedDomain.find(domainId, on: request.db) else {
            throw EntityNotFoundError.userBlockedDomainNotFound
        }
        
        let authorizationPayloadId = try request.requireUserId()
        guard userBlockedDomain.$user.id == authorizationPayloadId else {
            throw EntityForbiddenError.userDomainBlockedForbidden
        }
        
        userBlockedDomain.domain = userBlockedDomainDto.domain
        userBlockedDomain.reason = userBlockedDomainDto.reason

        try await userBlockedDomain.save(on: request.db)
        return UserBlockedDomainDto(from: userBlockedDomain)
    }
    
    /// Delete user's blocked domain from the database.
    ///
    /// The endpoint can be used for deleting existing user's blocked domain.
    ///
    /// > Important: Endpoint URL: `/api/v1/user-blocked-domains/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-blocked-domains/7267938074834522113" \
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
    /// - Throws: `UserBlockedDomainError.incorrectId` if incorrect id is specified.
    /// - Throws: `EntityNotFoundError.userBlockedDomainNotFound` if user's blocked domain not found.
    /// - Throws: `EntityForbiddenError.userDomainBlockedForbidden` if user cannot access specific user's blocked domain.
    @Sendable
    func delete(request: Request) async throws -> HTTPStatus {
        guard let domainIdString = request.parameters.get("id", as: String.self) else {
            throw UserBlockedDomainError.incorrectId
        }
        
        guard let domainId = domainIdString.toId() else {
            throw UserBlockedDomainError.incorrectId
        }
        
        guard let userBlockedDomain = try await UserBlockedDomain.find(domainId, on: request.db) else {
            throw EntityNotFoundError.userBlockedDomainNotFound
        }
        
        let authorizationPayloadId = try request.requireUserId()
        guard userBlockedDomain.$user.id == authorizationPayloadId else {
            throw EntityForbiddenError.userDomainBlockedForbidden
        }
        
        try await userBlockedDomain.delete(on: request.db)
        return HTTPStatus.ok
    }
    
    private func createNewUserBlockedDomainResponse(on request: Request, userBlockedDomain: UserBlockedDomain) async throws -> Response {
        let userBlockedDomainDto = UserBlockedDomainDto(from: userBlockedDomain)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(UserBlockedDomainsController.uri)/\(userBlockedDomain.stringId() ?? "")")
        
        return try await userBlockedDomainDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
