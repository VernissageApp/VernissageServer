//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Leaf

extension OAuthController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("oauth")
    
    func boot(routes: RoutesBuilder) throws {
        let authClientsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(OAuthController.uri)
            .grouped(UserAuthenticator())
        
        authClientsGroup
            .grouped(EventHandlerMiddleware(.oAuthAuthenticate))
            .grouped(CacheControlMiddleware(.noStore))
            .get("authorize", use: authenticate)
        
        authClientsGroup
            .grouped(EventHandlerMiddleware(.oAuthAuthenticateCallback))
            .grouped(CacheControlMiddleware(.noStore))
            .post("authorize", use: authenticateCallback)
        
        authClientsGroup
            .grouped(EventHandlerMiddleware(.oAuthAuthenticate))
            .grouped(CacheControlMiddleware(.noStore))
            .post("token", use: token)
    }
}

/// Controller for OAuth 2.0 endpoints.
///
/// This is implemetation of (RFC 6749): The OAuth 2.0 Authorization Framework.
/// The OAuth 2.0 authorization framework enables a third-party
/// application to obtain limited access to an HTTP service, either on
/// behalf of a resource owner by orchestrating an approval interaction
/// between the resource owner and the HTTP service, or by allowing the
/// third-party application to obtain access on its own behalf.  This
/// specification replaces and obsoletes the OAuth 1.0 protocol described
/// in RFC 5849.
struct OAuthController {
    private let allowedScopes = ["read", "write", "profile"]
    
    
    /// Authorization endpoint - used by the client to obtain authorization from
    /// the resource owner via user-agent redirection.
    ///
    /// The authorization endpoint is used to interact with the resource
    /// owner and obtain an authorization grant.  The authorization server
    /// MUST first verify the identity of the resource owner.  The way in
    /// which the authorization server authenticates the resource owner
    /// (e.g., username and password login, session cookies) is beyond the
    /// scope of this specification.
    ///
    /// For example, the client directs the user-agent to make the following
    /// HTTP request using TLS:
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/oauth/authorize?response_type=code&client_id=s6BhdRkqt3&state=xyz&redirect_uri=https%3A%2F%2Fclient%2Eexample%2Ecom%2Fcb" \
    /// -X GET
    /// ```
    ///
    /// After that request user is redirected to login page (it it's not already signed in)
    /// or to authorization page. After authorization redirection to specified `redirect_uri`
    /// is done (with `code` which can be replaced for the access token in token endpoint).
    @Sendable
    func authenticate(request: Request) async throws -> Response {
        let oAuthAuthenticateParameters = try request.query.decode(OAuthAuthenticateParametersDto.self)
        
        // Read parameters from Url.
        let redirectUri = oAuthAuthenticateParameters.redirectUri.string
        let state = oAuthAuthenticateParameters.state ?? ""
        let scope = oAuthAuthenticateParameters.scope
        
        // Generate dynamic properties used for security reason.
        let csrfToken = String.createRandomString(length: 64)
        let nonce = String.createRandomString(length: 32)
        
        // Download dynamic client by client id.
        let authenticationDynamicClientsService = request.application.services.authenticationDynamicClientsService
        guard let authDynamicClient = try await authenticationDynamicClientsService.get(id: oAuthAuthenticateParameters.clientId, on: request) else {
            return try await OAuthErrorDto("Client `\(oAuthAuthenticateParameters.clientId)` is not registered.", state: state).response(on: request)
        }
        
        // Check if specified redirect_uri has been registered with the client.
        let redirectUris = authDynamicClient.redirectUrisArray
        guard redirectUris.contains(where: { $0 == oAuthAuthenticateParameters.redirectUri.string }) == true else {
            return try await OAuthErrorDto("Redirect URI '\(oAuthAuthenticateParameters.redirectUri.string)' has not been registered in the client.", state: state)
                .response(on: request)
        }
        
        // Check if specified response_type has been registered with the client.
        let responseTypes = authDynamicClient.responseTypesArray
        guard responseTypes.contains(where: { $0 == oAuthAuthenticateParameters.responseType }) == true else {
            return try await OAuthErrorDto("Response type '\(oAuthAuthenticateParameters.responseType)' has not been registered in the client.", state: state)
                .response(on: request)
        }

        // All provided scopes have to be allowed scopes.
        let scopes = oAuthAuthenticateParameters.scope.components(separatedBy: " ")
        for scope in scopes {
            if self.allowedScopes.contains(where: { $0 == scope }) == false {
                return try await OAuthErrorDto("Scope '\(scope)' is not supported.", error: .invalidScope, state: state)
                    .response(on: request)
            }
            
            if authDynamicClient.scopesArray?.contains(where: { $0 == scope }) == false {
                return try await OAuthErrorDto("Scope '\(scope)' has not been registered in the client.", error: .invalidScope, state: state)
                    .response(on: request)
            }
        }
        
        // Check if current user is already signed in into the system (the Cookie or Bearer header exists in the request).
        guard let userPayload = request.auth.get(UserPayload.self) else {
            let queryParams: [(String, String?)] = [
                ("state", state),
                ("client_id", oAuthAuthenticateParameters.clientId),
                ("scope", scope),
                ("redirect_uri", redirectUri),
                ("nonce", nonce)
            ]
            
            // Construct the query string
            let queryString = queryParams.map { key, value in
                if let value = value {
                    return "\(key)=\(value)"
                } else {
                    return key
                }
            }.joined(separator: "&")
            
            // Combine the base URL and query string (redirection to Angular web application).
            let redirectURLString = "/login?\(queryString)"

            // When user is not signed in, we have to open the client page where user can sign in.
            // After that process he is redirected to the same endpoint (but cookie should be set up).
            return request.redirect(to: redirectURLString)
        }
        
        // Parse user id as an Integer.
        guard let userId = Int64(userPayload.id) else {
            return try await OAuthErrorDto("User id '\(userPayload.id)' cannot be paresed to correct integer.", error: .accessDenied, state: state)
                .response(on: request)
        }

        // Create information about current OAuth request.
        let oAuthClientRequestId = request.application.services.snowflakeService.generate()
        let oAuthClientRequest = try OAuthClientRequest(id: oAuthClientRequestId,
                                                        authDynamicClientId: authDynamicClient.requireID(),
                                                        userId: userId,
                                                        csrfToken: csrfToken,
                                                        redirectUri: redirectUri,
                                                        scope: scope,
                                                        state: state,
                                                        nonce: nonce)
        
        // Save information about current OAuth request to database.
        try await oAuthClientRequest.save(on: request.db)
                
        // User is signed in thus we can show page where he can autorize client to read/write to his account.
        let oAuthAuthorizePageDto = OAuthAuthorizePageDto(id: oAuthClientRequest.stringId() ?? "",
                                                          csrfToken: csrfToken,
                                                          state: state,
                                                          scopes: scope.components(separatedBy: " "),
                                                          userName: userPayload.userName,
                                                          userFullName: userPayload.name ?? userPayload.userName,
                                                          clientName: authDynamicClient.clientName ?? "")
        
        return try await request.view.render("authorize", oAuthAuthorizePageDto).encodeResponse(for: request)
    }

    /// Endpoint executed when user authorized the client to the scopes.
    ///
    /// That endpint check the validiy of all parametersm and if everything is
    /// valid, the redirection with `code` is returned.
    @Sendable
    func authenticateCallback(request: Request) async throws -> Response {
        let oAuthAuthenticateCallbackDto = try request.content.decode(OAuthAuthenticateCallbackDto.self)
        
        guard let oAuthClientRequestId = Int64(oAuthAuthenticateCallbackDto.id) else {
            return try await OAuthErrorDto("Client request id '\(oAuthAuthenticateCallbackDto.id)' cannot be paresed to correct integer.", state: oAuthAuthenticateCallbackDto.state)
                .response(on: request)
        }
        
        guard let oAuthClientRequest = try await OAuthClientRequest.query(on: request.db)
            .filter(\.$id == oAuthClientRequestId)
            .with(\.$authDynamicClient)
            .with(\.$user)
            .first() else {
            return try await OAuthErrorDto("Client request '\(oAuthAuthenticateCallbackDto.id)' not exists.", state: oAuthAuthenticateCallbackDto.state)
            .response(on: request)
        }
        
        guard oAuthAuthenticateCallbackDto.csrfToken == oAuthClientRequest.csrfToken else {
            return try await OAuthErrorDto("CSRF token '\(oAuthAuthenticateCallbackDto.csrfToken)' mismatch.", state: oAuthAuthenticateCallbackDto.state)
                .response(on: request)
        }
        
        // Generate code.
        let generatedCode = String.createRandomString(length: 32)
        
        // Save newly generated code into the database.
        oAuthClientRequest.code = generatedCode
        oAuthClientRequest.codeGeneratedAt = Date()
        
        oAuthClientRequest.authorizedAt = Date()
        try await oAuthClientRequest.save(on: request.db)
        
        // Combine the base URL and query string.
        let redirectURLString = "\(oAuthClientRequest.redirectUri)?code=\(generatedCode)"

        // Return redirection with generated code.
        return request.redirect(to: redirectURLString)
    }
    
    /// Token endpoint - used by the client to exchange an authorization
    /// grant for an access token, typically with client authentication.
    ///
    /// The token endpoint is used by the client to obtain an access token by
    /// presenting its authorization grant or refresh token.  The token
    /// endpoint is used with every authorization grant except for the
    /// implicit grant type (since an access token is issued directly).
    /// The means through which the client obtains the location of the token
    /// endpoint are beyond the scope of this specification, but the location
    /// is typically provided in the service documentation.
    @Sendable
    func token(request: Request) async throws -> Response {
        let oAuthTokenParamteresDto = try request.content.decode(OAuthTokenParamteresDto.self)
        
        // Depending on `grant_type` we have to create access token based on 'code' or refresh access token based on `refresh_token`.
        switch oAuthTokenParamteresDto.grantType {
        case "authorization_code":
            return try await self.generateAccessTokenByCode(oAuthTokenParamteresDto: oAuthTokenParamteresDto, on: request)
        case "client_credentials":
            return try await self.generateAccessTokenByClientSecret(oAuthTokenParamteresDto: oAuthTokenParamteresDto, on: request)
        case "refresh_token":
            return try await self.refreshAccessToken(oAuthTokenParamteresDto: oAuthTokenParamteresDto, on: request)
        default:
            return try await OAuthErrorDto("Grant type is not an 'authorization_code' or 'refresh_token'.").response(on: request)
        }
    }

    private func generateAccessTokenByCode(oAuthTokenParamteresDto: OAuthTokenParamteresDto, on request: Request) async throws -> Response {
        guard let code = oAuthTokenParamteresDto.code, code.isEmpty == false else {
            return try await OAuthErrorDto("Code have to be specified for 'authorization_code' grant type.").response(on: request)
        }
        
        guard let clientIdString = oAuthTokenParamteresDto.clientId, clientIdString.isEmpty == false else {
            return try await OAuthErrorDto("Client id have to be specified for 'authorization_code' grant type.").response(on: request)
        }
        
        guard let oAuthClientRequest = try await OAuthClientRequest.query(on: request.db)
            .filter(\.$code == code)
            .with(\.$authDynamicClient)
            .with(\.$user)
            .first() else {
            return try await OAuthErrorDto("Code '\(code)' is invalid.").response(on: request)
        }

        guard clientIdString == oAuthClientRequest.authDynamicClient.stringId() else {
            return try await OAuthErrorDto("Client id mismatch.").response(on: request)
        }
        
        guard oAuthClientRequest.authDynamicClient.grantTypesArray.contains("authorization_code") else {
            return try await OAuthErrorDto("Client does not support 'authorization_code' grant type.").response(on: request)
        }
        
        if let codeGeneratedAt = oAuthClientRequest.codeGeneratedAt, codeGeneratedAt.addingTimeInterval(60) < Date() {
            return try await OAuthErrorDto("Code '\(code)' expired (code is valid one minute).").response(on: request)
        }
        
        guard oAuthTokenParamteresDto.redirectUri == oAuthClientRequest.redirectUri else {
            return try await OAuthErrorDto("Redirect URI mismatch.").response(on: request)
        }
        
        // When client has been created with secret, we need to require also client_secret in 'authorization_code' flow.
        if let clientSecretFromDatabase = oAuthClientRequest.authDynamicClient.clientSecret {
            guard let clientSecretFromRequest = oAuthTokenParamteresDto.clientSecret, clientSecretFromRequest.isEmpty == false else {
                return try await OAuthErrorDto("Client secret have to be specified if the client was issued a client secret.").response(on: request)
            }

            guard clientSecretFromRequest == clientSecretFromDatabase else {
                return try await OAuthErrorDto("Client secret is invalid.").response(on: request)
            }
        }
        
        guard oAuthClientRequest.authorizedAt != nil else {
            return try await OAuthErrorDto("User not authorized the client.", error: .accessDenied).response(on: request)
        }
        
        let tokensService = request.application.services.tokensService
        let accessToken = try await tokensService.createAccessTokens(forUser: oAuthClientRequest.user,
                                                                     useCookies: false,
                                                                     useLongAccessToken: true,
                                                                     useApplication: oAuthClientRequest.authDynamicClient.clientName,
                                                                     useScopes: oAuthClientRequest.scopesArray,
                                                                     on: request)
        
        let oAuthTokenResponseDto = OAuthTokenResponseDto(accessToken: accessToken.accessToken,
                                                          tokenType: "bearer",
                                                          expiresIn: accessToken.accessTokenExpirationDate,
                                                          refreshToken: accessToken.refreshToken)
        
        return try await oAuthTokenResponseDto.encodeResponse(for: request)
    }
    
    private func generateAccessTokenByClientSecret(oAuthTokenParamteresDto: OAuthTokenParamteresDto, on request: Request) async throws -> Response {
        guard let clientSecret = oAuthTokenParamteresDto.clientSecret, clientSecret.isEmpty == false else {
            return try await OAuthErrorDto("Client secret have to be specified for 'client_credentials' grant type.").response(on: request)
        }
        
        guard let clientIdString = oAuthTokenParamteresDto.clientId, let clientId = Int64(clientIdString) else {
            return try await OAuthErrorDto("Correct client id have to be specified for 'client_credentials' grant type.").response(on: request)
        }
        
        guard let authDynamicClient = try await AuthDynamicClient.query(on: request.db)
            .filter(\.$id == clientId)
            .filter(\.$clientSecret == clientSecret)
            .with(\.$user)
            .first() else {
            return try await OAuthErrorDto("Wrong client credentials.").response(on: request)
        }
        
        guard authDynamicClient.grantTypesArray.contains("client_credentials") else {
            return try await OAuthErrorDto("Client does not support 'client_credentials' grant type.").response(on: request)
        }
        
        guard let user = authDynamicClient.user else {
            return try await OAuthErrorDto("Cannot use 'client_credentials' grant type for public client.").response(on: request)
        }
        
        guard authDynamicClient.redirectUrisArray.contains(where: { $0 == oAuthTokenParamteresDto.redirectUri }) else {
            return try await OAuthErrorDto("Redirect URI mismatch.").response(on: request)
        }
        
        let tokensService = request.application.services.tokensService
        let accessToken = try await tokensService.createAccessTokens(forUser: user,
                                                                     useCookies: false,
                                                                     useLongAccessToken: false,
                                                                     useApplication: authDynamicClient.clientName,
                                                                     useScopes: authDynamicClient.scopesArray,
                                                                     on: request)
        
        let oAuthTokenResponseDto = OAuthTokenResponseDto(accessToken: accessToken.accessToken,
                                                          tokenType: "bearer",
                                                          expiresIn: accessToken.accessTokenExpirationDate,
                                                          refreshToken: nil)
        
        return try await oAuthTokenResponseDto.encodeResponse(for: request)
    }
    
    private func refreshAccessToken(oAuthTokenParamteresDto: OAuthTokenParamteresDto, on request: Request) async throws -> Response {
        guard let oldRefreshToken = oAuthTokenParamteresDto.refreshToken, oldRefreshToken.isEmpty == false else {
            return try await OAuthErrorDto("Refresh token have to be specified for 'refresh_token' grant type.").response(on: request)
        }

        guard let clientIdString = oAuthTokenParamteresDto.clientId, let clientId = Int64(clientIdString) else {
            return try await OAuthErrorDto("Client id have to be specified for 'refresh_token' grant type.").response(on: request)
        }
        
        guard let authDynamicClient = try await AuthDynamicClient.query(on: request.db)
            .filter(\.$id == clientId)
            .first() else {
            return try await OAuthErrorDto("Client id is invalid.").response(on: request)
        }
        
        guard authDynamicClient.grantTypesArray.contains("refresh_token") else {
            return try await OAuthErrorDto("Client does not support 'refresh_token' grant type.").response(on: request)
        }
        
        // When client has been created with secret, we need to require also client_secret in 'authorization_code' flow.
        if let clientSecretFromDatabase = authDynamicClient.clientSecret {
            guard let clientSecretFromRequest = oAuthTokenParamteresDto.clientSecret, clientSecretFromRequest.isEmpty == false else {
                return try await OAuthErrorDto("Client secret have to be specified if the client was issued a client secret.").response(on: request)
            }

            guard clientSecretFromRequest == clientSecretFromDatabase else {
                return try await OAuthErrorDto("Client secret is invalid.").response(on: request)
            }
        }
        
        let tokensService = request.application.services.tokensService
        let refreshTokenFromDb = try await tokensService.validateRefreshToken(refreshToken: oldRefreshToken, on: request)
        let user = try await tokensService.getUserByRefreshToken(refreshToken: refreshTokenFromDb.token, on: request)

        let accessToken = try await tokensService.updateAccessTokens(forUser: user,
                                                                     refreshToken: refreshTokenFromDb,
                                                                     regenerateRefreshToken: true,
                                                                     useCookies: false,
                                                                     useLongAccessToken: true,
                                                                     useApplication: authDynamicClient.clientName,
                                                                     useScopes: authDynamicClient.scopesArray,
                                                                     on: request)
  
        let oAuthTokenResponseDto = OAuthTokenResponseDto(accessToken: accessToken.accessToken,
                                                          tokenType: "bearer",
                                                          expiresIn: accessToken.accessTokenExpirationDate,
                                                          refreshToken: accessToken.refreshToken)
        
        return try await oAuthTokenResponseDto.encodeResponse(for: request)
    }
}
