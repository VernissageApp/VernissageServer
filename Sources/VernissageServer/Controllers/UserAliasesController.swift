//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension UserAliasesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("user-aliases")
    
    func boot(routes: RoutesBuilder) throws {
        let userAliasesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(UserAliasesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        userAliasesGroup
            .grouped(EventHandlerMiddleware(.userAliasesList))
            .get(use: list)
        
        userAliasesGroup
            .grouped(EventHandlerMiddleware(.userAliasesCreate))
            .post(use: create)
        
        userAliasesGroup
            .grouped(EventHandlerMiddleware(.userAliasesDelete))
            .delete(":id", use: delete)
    }
}

/// Controller for managing user's aliases.
///
/// Controller, through which it is possible to manage user's aliases in the system.
/// Thanks to user's aliases users can move accounts from old instance to new (this) instance.
///
/// > Important: Base controller URL: `/api/v1/roles`.
final class UserAliasesController {

    /// Get all user's aliases.
    ///
    /// The endpoint through which it is possible to download a list of all user's aliases from the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/user-aliases`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-aliases" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [
    ///     {
    ///         "id": "7250729777261213697",
    ///         "alias": "account1@servera.com"
    ///     },
    ///     {
    ///         "id": "7250729777261215745",
    ///         "alias": "account2@serverb.com"
    ///     }
    /// ]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of user's aliases.
    func list(request: Request) async throws -> [UserAliasDto] {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        let userAliases = try await UserAlias.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .all()

        return userAliases.map { userAlias in UserAliasDto(id: userAlias.stringId(), alias: userAlias.alias) }
    }

    /// Create new user alias.
    ///
    /// Endpoint, used to add new alias to user account.
    ///
    /// > Important: Endpoint URL: `/api/v1/user-aliases`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-aliases" \
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
    ///     "alias": "alias1@server1.com"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7250729777261217793",
    ///     "alias": "alias1@server1.com"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about new user alias.
    ///
    /// - Throws: `UserAliasError.userAliasAlreadyExist` if user alias already exist.
    /// - Throws: `UserAliasError.cannotVerifyRemoteAccount` if cannot verify remote account.
    func create(request: Request) async throws -> Response {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let userAliasDto = try request.content.decode(UserAliasDto.self)
        try UserAliasDto.validate(content: request)
        
        let aliasNormalized = userAliasDto.alias.uppercased()
        let userAlias = try await UserAlias.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$aliasNormalized == aliasNormalized)
            .first()
        
        if userAlias != nil {
            throw UserAliasError.userAliasAlreadyExist
        }
        
        // Download user activity pub profile.
        let searchService = request.application.services.searchService
        guard let activityPubProfile = await searchService.getRemoteActivityPubProfile(userName: userAliasDto.alias, on: request) else {
            throw UserAliasError.cannotVerifyRemoteAccount
        }
        
        let newUserAlias = UserAlias(userId: authorizationPayloadId, alias: userAliasDto.alias, activityPubProfile: activityPubProfile)

        try await newUserAlias.save(on: request.db)
        return try await createNewUserAliasResponse(on: request, userAlias: newUserAlias)
    }
    
    /// Delete user's alias from the database.
    ///
    /// The endpoint can be used for deleting existing user's alias.
    ///
    /// > Important: Endpoint URL: `/api/v1/user-aliases/:id`.
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
    ///
    /// - Throws: `UserAliasError.incorrectUserAliasId` if user alias is incorrect.
    /// - Throws: `EntityNotFoundError.userAliasNotFound` if user alias not exists.
    func delete(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let userAliasIdString = request.parameters.get("id", as: String.self) else {
            throw UserAliasError.incorrectUserAliasId
        }
        
        guard let userAliasId = userAliasIdString.toId() else {
            throw UserAliasError.incorrectUserAliasId
        }
        
        guard let userAlias = try await UserAlias.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$id == userAliasId)
            .first() else {
            throw EntityNotFoundError.userAliasNotFound
        }

        try await userAlias.delete(on: request.db)
        return HTTPStatus.ok
    }
    
    private func createNewUserAliasResponse(on request: Request, userAlias: UserAlias) async throws -> Response {
        let userAliasDto = UserAliasDto(id: userAlias.stringId(), alias: userAlias.alias)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(UserAliasesController.uri)/@\(userAlias.stringId() ?? "")")
        
        return try await userAliasDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
