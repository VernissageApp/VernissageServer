//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension AuthenticationClientsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("auth-clients")
    
    func boot(routes: RoutesBuilder) throws {
        let authClientsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(AuthenticationClientsController.uri)
        
        authClientsGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsAdministratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.authClientsCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)

        authClientsGroup
            .grouped(EventHandlerMiddleware(.authClientsList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)

        authClientsGroup
            .grouped(EventHandlerMiddleware(.authClientsRead))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":id", use: read)
        
        authClientsGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsAdministratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.authClientsUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .put(":id", use: update)
        
        authClientsGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsAdministratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.authClientsDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", use: delete)
    }
}

/// Controller for managing auth clients.
struct AuthenticationClientsController {

    /// Create new authentication client.
    @Sendable
    func create(request: Request) async throws -> Response {
        let authClientsService = request.application.services.authenticationClientsService
        let authClientDto = try request.content.decode(AuthClientDto.self)
        try AuthClientDto.validate(content: request)

        try await authClientsService.validate(uri: authClientDto.uri, authClientId: nil, on: request.db)
        let authClient = try await self.createAuthClient(on: request, authClientDto: authClientDto)
        let response = try await self.createNewAuthClientResponse(on: request, authClient: authClient)
        
        return response
    }

    /// Get all authentication clients.
    @Sendable
    func list(request: Request) async throws -> [AuthClientDto] {
        let authClients = try await AuthClient.query(on: request.db).all()
        return authClients.map { authClient in AuthClientDto(from: authClient) }
    }

    /// Get specific authentication client.
    @Sendable
    func read(request: Request) async throws -> AuthClientDto {
        guard let authClientIdString = request.parameters.get("id", as: String.self) else {
            throw AuthClientError.incorrectAuthClientId
        }
        
        guard let authClientId = authClientIdString.toId() else {
            throw AuthClientError.incorrectAuthClientId
        }

        let authClient = try await self.getAuthClientById(on: request, authClientId: authClientId)
        guard let authClient = authClient else {
            throw EntityNotFoundError.authClientNotFound
        }
        
        return AuthClientDto(from: authClient)
    }

    /// Update specific authentication client.
    @Sendable
    func update(request: Request) async throws -> AuthClientDto {

        guard let authClientIdString = request.parameters.get("id", as: String.self) else {
            throw AuthClientError.incorrectAuthClientId
        }
        
        guard let authClientId = authClientIdString.toId() else {
            throw AuthClientError.incorrectAuthClientId
        }
        
        let authClientsService = request.application.services.authenticationClientsService
        let authClientDto = try request.content.decode(AuthClientDto.self)
        try AuthClientDto.validate(content: request)
        
        let authClient = try await self.getAuthClientById(on: request, authClientId: authClientId)
        guard let authClient = authClient else {
            throw EntityNotFoundError.authClientNotFound
        }
        
        try await authClientsService.validate(uri: authClientDto.uri, authClientId: authClient.id, on: request.db)
        try await self.updateAuthClient(on: request, from: authClientDto, to: authClient)

        return AuthClientDto(from: authClient)
    }

    /// Delete specific authentication client.
    @Sendable
    func delete(request: Request) async throws -> HTTPStatus {
        guard let authClientIdString = request.parameters.get("id", as: String.self) else {
            throw AuthClientError.incorrectAuthClientId
        }

        guard let authClientId = authClientIdString.toId() else {
            throw AuthClientError.incorrectAuthClientId
        }
        
        let authClient = try await self.getAuthClientById(on: request, authClientId: authClientId)
        guard let authClient = authClient else {
            throw EntityNotFoundError.authClientNotFound
        }
        
        try await authClient.delete(on: request.db)

        return HTTPStatus.ok
    }

    private func createAuthClient(on request: Request, authClientDto: AuthClientDto) async throws -> AuthClient {
        let id = request.application.services.snowflakeService.generate()
        let authClient = AuthClient(from: authClientDto, withid: id)
        try await authClient.save(on: request.db)
        
        return authClient
    }

    private func createNewAuthClientResponse(on request: Request, authClient: AuthClient) async throws -> Response {
        let createdAuthClientDto = AuthClientDto(from: authClient)
                
        let response = try await createdAuthClientDto.encodeResponse(for: request)
        response.headers.replaceOrAdd(name: .location, value: "/\(AuthenticationClientsController.uri)/\(authClient.stringId() ?? "")")
        response.status = .created

        return response
    }

    private func getAuthClientById(on request: Request, authClientId: Int64) async throws -> AuthClient? {
        return try await AuthClient.find(authClientId, on: request.db)
    }

    private func updateAuthClient(on request: Request, from authClientDto: AuthClientDto, to authClient: AuthClient) async throws {
        authClient.type = authClientDto.type
        authClient.name = authClientDto.name
        authClient.uri = authClientDto.uri
        authClient.tenantId = authClientDto.tenantId
        authClient.clientId = authClientDto.clientId
        authClient.clientSecret = authClientDto.clientSecret
        authClient.callbackUrl = authClientDto.callbackUrl
        authClient.svgIcon = authClientDto.svgIcon

        try await authClient.update(on: request.db)
    }
}
