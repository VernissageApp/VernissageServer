import Vapor

final class AuthenticationClientsController: RouteCollection {

    public static let uri: PathComponent = .constant("auth-clients")
    
    func boot(routes: RoutesBuilder) throws {
        let authClientsGroup = routes
            .grouped(AuthenticationClientsController.uri)
        
        authClientsGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsSuperUserMiddleware())
            .grouped(EventHandlerMiddleware(.authClientsCreate))
            .post(use: create)

        authClientsGroup
            .grouped(EventHandlerMiddleware(.authClientsList))
            .get(use: list)

        authClientsGroup
            .grouped(EventHandlerMiddleware(.authClientsRead))
            .get(":id", use: read)
        
        authClientsGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsSuperUserMiddleware())
            .grouped(EventHandlerMiddleware(.authClientsUpdate))
            .put(":id", use: update)
        
        authClientsGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsSuperUserMiddleware())
            .grouped(EventHandlerMiddleware(.authClientsDelete))
            .delete(":id", use: delete)
    }

    /// Create new authentication client.
    func create(request: Request) async throws -> Response {
        let authClientsService = request.application.services.authenticationClientsService
        let authClientDto = try request.content.decode(AuthClientDto.self)
        try AuthClientDto.validate(content: request)

        try await authClientsService.validateUri(on: request, uri: authClientDto.uri, authClientId: nil)
        let authClient = try await self.createAuthClient(on: request, authClientDto: authClientDto)
        let response = try await self.createNewAuthClientResponse(on: request, authClient: authClient)
        
        return response
    }

    /// Get all authentication clients.
    func list(request: Request) async throws -> [AuthClientDto] {
        let authClients = try await AuthClient.query(on: request.db).all()
        return authClients.map { authClient in AuthClientDto(from: authClient) }
    }

    /// Get specific authentication client.
    func read(request: Request) async throws -> AuthClientDto {
        guard let authClientId = request.parameters.get("id", as: UUID.self) else {
            throw AuthClientError.incorrectAuthClientId
        }

        let authClient = try await self.getAuthClientById(on: request, authClientId: authClientId)
        guard let authClient = authClient else {
            throw EntityNotFoundError.authClientNotFound
        }
        
        return AuthClientDto(from: authClient)
    }

    /// Update specific authentication client.
    func update(request: Request) async throws -> AuthClientDto {

        guard let authClientId = request.parameters.get("id", as: UUID.self) else {
            throw AuthClientError.incorrectAuthClientId
        }
        
        let authClientsService = request.application.services.authenticationClientsService
        let authClientDto = try request.content.decode(AuthClientDto.self)
        try AuthClientDto.validate(content: request)
        
        let authClient = try await self.getAuthClientById(on: request, authClientId: authClientId)
        guard let authClient = authClient else {
            throw EntityNotFoundError.authClientNotFound
        }
        
        try await authClientsService.validateUri(on: request, uri: authClientDto.uri, authClientId: authClient.id)
        try await self.updateAuthClient(on: request, from: authClientDto, to: authClient)

        return AuthClientDto(from: authClient)
    }

    /// Delete specific authentication client.
    func delete(request: Request) async throws -> HTTPStatus {
        guard let authClientId = request.parameters.get("id", as: UUID.self) else {
            throw AuthClientError.incorrectAuthClientId
        }

        let authClient = try await self.getAuthClientById(on: request, authClientId: authClientId)
        guard let authClient = authClient else {
            throw EntityNotFoundError.authClientNotFound
        }
        
        try await authClient.delete(on: request.db)

        return HTTPStatus.ok
    }

    private func createAuthClient(on request: Request, authClientDto: AuthClientDto) async throws-> AuthClient {
        let authClient = AuthClient(from: authClientDto)
        try await authClient.save(on: request.db)
        
        return authClient
    }

    private func createNewAuthClientResponse(on request: Request, authClient: AuthClient) async throws -> Response {
        let createdAuthClientDto = AuthClientDto(from: authClient)
                
        let response = try await createdAuthClientDto.encodeResponse(for: request)
        response.headers.replaceOrAdd(name: .location, value: "/\(AuthenticationClientsController.uri)/\(authClient.id?.uuidString ?? "")")
        response.status = .created

        return response
    }

    private func getAuthClientById(on request: Request, authClientId: UUID) async throws -> AuthClient? {
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
