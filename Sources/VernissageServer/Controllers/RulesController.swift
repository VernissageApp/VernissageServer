//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension RulesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("rules")

    func boot(routes: RoutesBuilder) throws {
        let rulesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(RulesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())

        rulesGroup
            .grouped(EventHandlerMiddleware(.rulesList))
            .get(use: list)
        
        rulesGroup
            .grouped(EventHandlerMiddleware(.rulesCreate))
            .post(use: create)

        rulesGroup
            .grouped(EventHandlerMiddleware(.rulesUpdate))
            .put(":id", use: update)
        
        rulesGroup
            .grouped(EventHandlerMiddleware(.rulesDelete))
            .delete(":id", use: delete)
    }
}

/// Controls basic operations for instance rules.
///
/// With this controller, the administrator/moderator can manage instance rules.
///
/// > Important: Base controller URL: `/api/v1/rules`.
final class RulesController {
    /// List of instance rules.
    ///
    /// The endpoint returns a list of all instance rules added to the system.
    /// Only administrators and moderators have access to the list.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/rules`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/rules" \
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
    ///             "order": 1,
    ///             "text": "Porn is forbidden."
    ///         },
    ///         {
    ///             "id": "7332804261530576897",
    ///             "order": 2,
    ///             "text": "Spam is forbidden."
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
    /// - Returns: List of paginable rules.
    func list(request: Request) async throws -> PaginableResultDto<RuleDto> {
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let rulesFromDatabase = try await Rule.query(on: request.db)
            .sort(\.$order, .ascending)
            .paginate(PageRequest(page: page, per: size))
        
        let rulesDtos = rulesFromDatabase.items.map { domain in
            RuleDto(from: domain)
        }

        return PaginableResultDto(
            data: rulesDtos,
            page: rulesFromDatabase.metadata.page,
            size: rulesFromDatabase.metadata.per,
            total: rulesFromDatabase.metadata.total
        )
    }
    
    /// Create new instance rule.
    ///
    /// The endpoint can be used for creating new instance rule.
    ///
    /// > Important: Endpoint URL: `/api/v1/rules`.
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
    ///     "order": 1,
    ///     "text": "Everything is forbidden."
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7267938074834522113",
    ///     "order": 1,
    ///     "text": "Everything is forbidden."
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: New added entity.
    func create(request: Request) async throws -> Response {
        let ruleDto = try request.content.decode(RuleDto.self)
        try RuleDto.validate(content: request)
        
        let rule = Rule(order: ruleDto.order, text: ruleDto.text)

        try await rule.save(on: request.db)
        return try await createNewRuleResponse(on: request, rule: rule)
    }
    
    /// Update instance rule in the database.
    ///
    /// The endpoint can be used for updating existing instance rule.
    ///
    /// > Important: Endpoint URL: `/api/v1/rules/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/rules/7267938074834522113" \
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
    ///     "order": 1,
    ///     "text": "Everything is forbidden."
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7267938074834522113",
    ///     "order": 1,
    ///     "text": "Everything is forbidden."
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Updated entity.
    func update(request: Request) async throws -> RuleDto {
        let ruleDto = try request.content.decode(RuleDto.self)
        try RuleDto.validate(content: request)
        
        guard let ruleIdString = request.parameters.get("id", as: String.self) else {
            throw RuleError.incorrectRuleId
        }
        
        guard let ruleId = ruleIdString.toId() else {
            throw RuleError.incorrectRuleId
        }
        
        guard let rule = try await Rule.find(ruleId, on: request.db) else {
            throw EntityNotFoundError.ruleNotFound
        }
        
        rule.order = ruleDto.order
        rule.text = ruleDto.text

        try await rule.save(on: request.db)
        return RuleDto(from: rule)
    }
    
    /// Delete instance rule from the database.
    ///
    /// The endpoint can be used for deleting existing instance rule.
    ///
    /// > Important: Endpoint URL: `/api/v1/rules/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/rules/7267938074834522113" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Http status code.
    func delete(request: Request) async throws -> HTTPStatus {
        guard let ruleIdString = request.parameters.get("id", as: String.self) else {
            throw RuleError.incorrectRuleId
        }
        
        guard let ruleId = ruleIdString.toId() else {
            throw RuleError.incorrectRuleId
        }
        
        guard let rule = try await Rule.find(ruleId, on: request.db) else {
            throw EntityNotFoundError.ruleNotFound
        }
        
        try await rule.delete(on: request.db)
        return HTTPStatus.ok
    }
    
    private func createNewRuleResponse(on request: Request, rule: Rule) async throws -> Response {
        let ruleDto = RuleDto(from: rule)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(RulesController.uri)/@\(rule.stringId() ?? "")")
        
        return try await ruleDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
