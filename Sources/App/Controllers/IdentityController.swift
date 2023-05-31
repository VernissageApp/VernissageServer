import Vapor
import Fluent
import JWTKit

final class IdentityController: RouteCollection {

    public static let uri: PathComponent = .constant("identity")

    func boot(routes: RoutesBuilder) throws {
        let identityGroup = routes.grouped(IdentityController.uri)

        identityGroup.get("authenticate", ":uri", use: authenticate)
        identityGroup.get("callback", ":uri", use: callback)
        identityGroup.post("login", use: login)
    }
    
    /// Redirect to external authentication provider.
    func authenticate(request: Request) async throws -> Response {
        guard let uri = request.parameters.get("uri") else {
            throw OpenIdConnectError.invalidClientName
        }
        
        let externalUsersService = request.application.services.externalUsersService
        let authClient = try await AuthClient.query(on: request.db).filter(\.$uri == uri).first()

        guard let authClient = authClient else {
            throw OpenIdConnectError.clientNotFound
        }
        
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let location = try externalUsersService.getRedirectLocation(authClient: authClient, baseAddress: baseAddress)
        return request.redirect(to: location, type: .permanent)
    }
    
    /// Callback from external authentication provider.
    func callback(request: Request) async throws -> Response {
        guard let uri = request.parameters.get("uri") else {
            throw OpenIdConnectError.invalidClientName
        }
        
        let callbackResponse = try request.query.decode(OAuthCallback.self)
        guard let code = callbackResponse.code else {
            throw OpenIdConnectError.codeTokenNotFound
        }
        
        let externalUsersService = request.application.services.externalUsersService

        // Get AuthClient object.
        let authClientFromDb = try await AuthClient.query(on: request.db).filter(\.$uri == uri).first()
        guard let authClientFromDb = authClientFromDb else {
            throw OpenIdConnectError.clientNotFound
        }
        
        // Send POST to token endpoint.
        let response = try await self.postOAuthRequest(on: request, for: authClientFromDb, code: code)
        
        // Validate token from OAuth provider.
        let oauthUserFromToken = try await self.getOAuthUser(on: request, from: response, type: authClientFromDb.type)

        // Check if external user is registered.
        let (user, externalUser) = try await externalUsersService.getRegisteredExternalUser(on: request, user: oauthUserFromToken)

        // Create user if not exists.
        let createdUser = try await self.createUserIfNotExists(on: request, userFromDb: user, oauthUser: oauthUserFromToken)
        
        // Create external user if not exists.
        let createdExternalUser = try await self.createExternalUserIfNotExists(on: request,
                                                                               authClient: authClientFromDb,
                                                                               oauthUser: oauthUserFromToken,
                                                                               user: createdUser,
                                                                               externalUserFromDb: externalUser)
        
        // Generate authentication token.
        let authenticationToken = String.createRandomString(length: 100)
        createdExternalUser.authenticationToken = authenticationToken
        createdExternalUser.tokenCreatedAt = Date()
        
        // Save authentication token.
        try await createdExternalUser.save(on: request.db)
        
        // Redirect to callback url.
        return request.redirect(to: "\(authClientFromDb.callbackUrl)?authenticateToken=\(authenticationToken)", type: .permanent)
    }
    
    /// Sign-in user based on authenticate token.
    func login(request: Request) async throws -> AccessTokenDto {
        let loginRequestDto = try request.content.decode(ExternalLoginRequestDto.self)
        let usersService = request.application.services.usersService

        let user = try await usersService.login(on: request, authenticateToken: loginRequestDto.authenticateToken)
        let tokensService = request.application.services.tokensService
        let accessToken = try await tokensService.createAccessTokens(on: request, forUser: user)
        
        return accessToken
    }
    
    private func postOAuthRequest(on request: Request, for authClient: AuthClient, code: String) async throws -> ClientResponse {
        let externalUsersService = request.application.services.externalUsersService
        
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        
        let oauthRequest = externalUsersService.getOauthRequest(authClient: authClient, baseAddress: baseAddress, code: code)
        let clientResponse = try await request.client.post(URI(string: oauthRequest.url), headers: HTTPHeaders()) { clientRequest in
            try clientRequest.content.encode(oauthRequest, as: .urlEncodedForm)
        }
        
        return clientResponse
    }
    
    private func getOAuthUser(on request: Request, from response: ClientResponse, type: AuthClientType) async throws -> OAuthUser {
        let accessTokenResponse = try response.content.decode(OAuthResponse.self)
        
        switch type {
        case .apple:
            let jwt = try await request.jwt.apple.verify(applicationIdentifier: accessTokenResponse.idToken!)
            return OAuthUser(uniqueId: jwt.subject.value,
                             email: jwt.email!,
                             familyName: nil,
                             givenName: nil,
                             name: nil)
            
        case .google:
            let jwt = try await request.jwt.google.verify(accessTokenResponse.idToken!)
            return OAuthUser(uniqueId: jwt.subject.value,
                             email: jwt.email!,
                             familyName: jwt.familyName,
                             givenName: jwt.givenName,
                             name: jwt.name)
        case .microsoft:
            let jwt = try await request.jwt.microsoft.verify(accessTokenResponse.idToken!)
            return OAuthUser(uniqueId: jwt.subject.value,
                             email: jwt.email!,
                             familyName: "",
                             givenName: "",
                             name: jwt.name)
        }
    }
    
    private func createExternalUserIfNotExists(on request: Request,
                                               authClient: AuthClient,
                                               oauthUser: OAuthUser,
                                               user: User,
                                               externalUserFromDb: ExternalUser?) async throws -> ExternalUser {
        
        if let externalUserFromDb = externalUserFromDb {
            return externalUserFromDb
        }
        
        let externalUser = ExternalUser(type: authClient.type,
                                        externalId: oauthUser.uniqueId,
                                        userId: user.id!)
        
        try await externalUser.save(on: request.db)
        return externalUser
    }
    
    private func createUserIfNotExists(on request: Request,
                                       userFromDb: User?,
                                       oauthUser: OAuthUser
    ) async throws -> User {

        if let userFromDb = userFromDb {
            return userFromDb
        }
        
        let rolesService = request.application.services.rolesService
        let usersService = request.application.services.usersService
        
        let salt = Password.generateSalt()
        let passwordHash = try Password.hash(UUID.init().uuidString, withSalt: salt)
        let gravatarHash = usersService.createGravatarHash(from: oauthUser.email)
        
        let user = User(fromOAuth: oauthUser,
                        withPassword: passwordHash,
                        salt: salt,
                        gravatarHash: gravatarHash)

        try await user.save(on: request.db)
        let roles = try await rolesService.getDefault(on: request)
        
        await withThrowingTaskGroup(of: Void.self) { group in
            for role in roles {
                group.addTask {
                    try await user.$roles.attach(role, on: request.db)
                }
            }
        }
        
        return user
    }
}
