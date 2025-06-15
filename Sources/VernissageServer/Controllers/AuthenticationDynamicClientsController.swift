//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension AuthenticationDynamicClientsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("oauth-dynamic-clients")
    
    func boot(routes: RoutesBuilder) throws {
        let authClientsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(AuthenticationDynamicClientsController.uri)
        
        authClientsGroup
            .grouped(EventHandlerMiddleware(.authDynamicClientsCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: register)
    }
}

/// Controller for registering OAuth dynamic clients.
struct AuthenticationDynamicClientsController {

    /// Register new dynamic OAuth client.
    @Sendable
    func register(request: Request) async throws -> Response {
        let authenticationDynamicClientsService = request.application.services.authenticationDynamicClientsService
        let registerOAuthClientRequestDto = try request.content.decode(RegisterOAuthClientRequestDto.self)
        try RegisterOAuthClientRequestDto.validate(content: request)

        let authDynamicClient = try await authenticationDynamicClientsService.create(on: request, registerOAuthClientRequestDto: registerOAuthClientRequestDto)
        let response = try await self.createNewAuthClientResponse(on: request, authDynamicClient: authDynamicClient)
        
        return response
    }

    private func createNewAuthClientResponse(on request: Request, authDynamicClient: AuthDynamicClient) async throws -> Response {
        let createdAuthClientDto = RegisterOAuthClientResponseDto(from: authDynamicClient)
                
        let response = try await createdAuthClientDto.encodeResponse(for: request)
        response.headers.replaceOrAdd(name: .location, value: "/\(AuthenticationDynamicClientsController.uri)/\(authDynamicClient.stringId() ?? "")")
        response.status = .created

        return response
    }
}
