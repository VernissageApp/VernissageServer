//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension AuthenticationDynamicClientsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("auth-dynamic-clients")
    
    func boot(routes: RoutesBuilder) throws {
        let authClientsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(AuthenticationDynamicClientsController.uri)
            .grouped(UserAuthenticator())
        
        authClientsGroup
            .grouped(EventHandlerMiddleware(.authDynamicClientsCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: register)
    }
}

/// Controller for registering OAuth dynamic clients.
///
/// This is implemetation of (RFC 7591): OAuth 2.0 Dynamic Client Registration Protocol.
/// In order for an OAuth 2.0 (RFC6749) client to utilize an OAuth 2.0
/// authorization server, the client needs specific information to
/// interact with the server, including an OAuth 2.0 client identifier to
/// use at that server.
struct AuthenticationDynamicClientsController {

    /// Register new dynamic OAuth client.
    ///
    /// > Important: Endpoint URL: `/api/v1/auth-dynamic-clients`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/auth-dynamic-clients" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "client_name": "Vernissage iOS",
    ///     "client_uri": "https://vernissage-ios.photos/",
    ///     "redirect_uris": [
    ///         "vernissage-ios://oauth-callback"
    ///     ],
    ///     "grant_types": [
    ///         "authorization_code"
    ///         "refresh_token"
    ///     ],
    ///     "response_types": [
    ///         "code"
    ///     ],
    ///     "scope": "read write profile",
    ///     "contacts": [
    ///         "admin@vernissage-ios.photos"
    ///     ],
    ///     "software_id": "3818973d-76bd-40cb-ac1c-7ac7d42cd69c",
    ///     "software_version": "1.0.0"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "client_id": "7516147615008820038",
    ///     "client_secret": "j5jdn75jrkgm93fehgncbt96iekgmtn3",
    ///     "client_id_issued_at": "1750226513",
    ///     "client_secret_expires_at": "1750236534"
    ///     "client_name": "Vernissage iOS",
    ///     "client_uri": "https://vernissage-ios.photos/",
    ///     "redirect_uris": [
    ///         "vernissage-ios://oauth-callback"
    ///     ],
    ///     "grant_types": [
    ///         "authorization_code",
    ///         "refresh_token"
    ///     ],
    ///     "response_types": [
    ///         "code"
    ///     ],
    ///     "scope": "read write profile",
    ///     "contacts": [
    ///         "admin@vernissage-ios.photos"
    ///     ],
    ///     "software_id": "3818973d-76bd-40cb-ac1c-7ac7d42cd69c",
    ///     "software_version": "1.0.0"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``RegisterOAuthClientRequestDto``.
    ///
    /// - Returns: Registered OAuth client.
    @Sendable
    func register(request: Request) async throws -> Response {
        let authenticationDynamicClientsService = request.application.services.authenticationDynamicClientsService
        let registerOAuthClientRequestDto = try request.content.decode(RegisterOAuthClientRequestDto.self)
        try RegisterOAuthClientRequestDto.validate(content: request)

        guard registerOAuthClientRequestDto.redirectUris.count > 0 else {
            return try await RegisterOAuthClientErrorDto("Redirect URI is required.").response(on: request)
        }
        
        // Based on RFC we have to validate grant type and response type correlation (https://datatracker.ietf.org/doc/html/rfc7591#section-2.1).
        for grantType in registerOAuthClientRequestDto.grantTypes {
            switch grantType {
            case .authorizationCode:
                guard registerOAuthClientRequestDto.responseTypes.isEmpty || registerOAuthClientRequestDto.responseTypes.contains(where: { $0 == .code }) else {
                    return try await RegisterOAuthClientErrorDto("Response type 'code' is required for 'authorization_code'.")
                        .response(on: request)
                }
            case .clientCredentials:
                guard registerOAuthClientRequestDto.tokenEndpointAuthMethod == .clientSecretPost || registerOAuthClientRequestDto.tokenEndpointAuthMethod == .clientSecretBasic else {
                    return try await RegisterOAuthClientErrorDto("For 'client_credentials' grant type, 'client_secret_basic' or 'client_secret_post' token endpoint authentication method is required.")
                        .response(on: request)
                }
                
                guard request.userId != nil else {
                    return try await RegisterOAuthClientErrorDto("Client credentials grant type requires authentication (specify 'Authenticate: Bearer' header).")
                        .response(on: request)
                }
                break;
            case .refreshToken:
                break;
            default:
                return try await RegisterOAuthClientErrorDto("Grant type '\(grantType)' is not supported.").response(on: request)
            }
        }
        
        guard registerOAuthClientRequestDto.responseTypes.contains(where: { $0 == .token }) == false else {
            return try await RegisterOAuthClientErrorDto("Response type 'token' is not supported (implicit grant type is not supported).")
                .response(on: request)
        }
        
        let authDynamicClient = try await authenticationDynamicClientsService.create(basedOn: registerOAuthClientRequestDto, for: request.userId, on: request)
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
