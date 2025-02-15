//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension InstanceBlockedDomainsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("instance-blocked-domains")

    func boot(routes: RoutesBuilder) throws {
        let domainsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(InstanceBlockedDomainsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())

        domainsGroup
            .grouped(EventHandlerMiddleware(.instanceBlockedDomainsList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        domainsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.instanceBlockedDomainsCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)

        domainsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.instanceBlockedDomainsUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .put(":id", use: update)
        
        domainsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.instanceBlockedDomainsDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", use: delete)
    }
}

/// Controls basic operations for instance blocked domains.
///
/// With this controller, the administrator/moderator can manage instance blocked domains.
///
/// > Important: Base controller URL: `/api/v1/instance-blocked-domains`.
struct InstanceBlockedDomainsController {

    /// List of instance blocked domains.
    ///
    /// The endpoint returns a list of all instance blocked domains added to the system.
    /// Only administrators and moderators have access to the list.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/instance-blocked-domains`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/instance-blocked-domains" \
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
    /// - Returns: List of paginable users.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<InstanceBlockedDomainDto> {
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let domainsFromDatabase = try await InstanceBlockedDomain.query(on: request.db)
            .sort(\.$domain, .ascending)
            .paginate(PageRequest(page: page, per: size))
        
        let domainsDtos = domainsFromDatabase.items.map { domain in
            InstanceBlockedDomainDto(from: domain)
        }

        return PaginableResultDto(
            data: domainsDtos,
            page: domainsFromDatabase.metadata.page,
            size: domainsFromDatabase.metadata.per,
            total: domainsFromDatabase.metadata.total
        )
    }
    
    /// Create new instance blocked domain.
    ///
    /// The endpoint can be used for creating new instance blocked domains.
    ///
    /// > Important: Endpoint URL: `/api/v1/instance-blocked-domains`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/instance-blocked-domains" \
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
        let instanceBlockedDomainDto = try request.content.decode(InstanceBlockedDomainDto.self)
        try InstanceBlockedDomainDto.validate(content: request)
        
        let id = request.application.services.snowflakeService.generate()
        let instanceBlockedDomain = InstanceBlockedDomain(id: id,
                                                          domain: instanceBlockedDomainDto.domain,
                                                          reason: instanceBlockedDomainDto.reason)

        try await instanceBlockedDomain.save(on: request.db)
        return try await createNewInstanceBlockedDomainResponse(on: request, instanceBlockedDomain: instanceBlockedDomain)
    }
    
    /// Update instance blocked domain in the database.
    ///
    /// The endpoint can be used for updating existing instance blocked domain.
    ///
    /// > Important: Endpoint URL: `/api/v1/instance-blocked-domains/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/instance-blocked-domains/7267938074834522113" \
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
    @Sendable
    func update(request: Request) async throws -> InstanceBlockedDomainDto {
        let instanceBlockedDomainDto = try request.content.decode(InstanceBlockedDomainDto.self)
        try InstanceBlockedDomainDto.validate(content: request)
        
        guard let domainIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let domainId = domainIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        guard let instanceBlockedDomain = try await InstanceBlockedDomain.find(domainId, on: request.db) else {
            throw EntityNotFoundError.instanceBlockedDomainNotFound
        }
        
        instanceBlockedDomain.domain = instanceBlockedDomainDto.domain
        instanceBlockedDomain.reason = instanceBlockedDomainDto.reason

        try await instanceBlockedDomain.save(on: request.db)
        return InstanceBlockedDomainDto(from: instanceBlockedDomain)
    }
    
    /// Delete instance blocked domain from the database.
    ///
    /// The endpoint can be used for deleting existing instance blocked domain.
    ///
    /// > Important: Endpoint URL: `/api/v1/instance-blocked-domains/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/instance-blocked-domains/7267938074834522113" \
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
        guard let domainIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let domainId = domainIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        guard let instanceBlockedDomain = try await InstanceBlockedDomain.find(domainId, on: request.db) else {
            throw EntityNotFoundError.instanceBlockedDomainNotFound
        }
        
        try await instanceBlockedDomain.delete(on: request.db)
        return HTTPStatus.ok
    }
    
    private func createNewInstanceBlockedDomainResponse(on request: Request, instanceBlockedDomain: InstanceBlockedDomain) async throws -> Response {
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(from: instanceBlockedDomain)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(InstanceBlockedDomainsController.uri)/@\(instanceBlockedDomain.stringId() ?? "")")
        
        return try await instanceBlockedDomainDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
