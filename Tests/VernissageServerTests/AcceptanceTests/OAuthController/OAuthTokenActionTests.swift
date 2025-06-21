//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("OAuth (POST /oauth/token)", .serialized, .tags(.oAuth))
    struct OAuthTokenActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Access token should be returned for correct authorization code")
        func accessTokenShouldBeReturnedForCorrectAuthorizationCode() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthTokenResponseDto = try response.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .ok, "Response http status code should be ok (200).")
            #expect(oAuthTokenResponseDto.accessToken.isEmpty == false, "Access token have to be returned.")
            #expect(oAuthTokenResponseDto.refreshToken?.isEmpty == false, "Refresh token have to be returned.")
        }
        
        @Test("Access token should be returned for correct authorization code and private client")
        func accessTokenShouldBeReturnedForCorrectAuthorizationCodeAndPrivateClient() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "olekgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code],
                                                                                  userId: user.requireID())
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage&client_secret=\(authDynamicClient.clientSecret  ?? "")".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthTokenResponseDto = try response.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .ok, "Response http status code should be ok (200).")
            #expect(oAuthTokenResponseDto.accessToken.isEmpty == false, "Access token have to be returned.")
            #expect(oAuthTokenResponseDto.refreshToken?.isEmpty == false, "Refresh token have to be returned.")
        }
        
        @Test("Access token should be returned for correct client credentials")
        func accessTokenShouldBeReturnedForCorrectClientCredentials() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "mariangibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.clientCredentials],
                                                                                  responseTypes: [.code],
                                                                                  userId: user.requireID())

            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=client_credentials&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/vernissage&client_secret=\(authDynamicClient.clientSecret ?? "")".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthTokenResponseDto = try response.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .ok, "Response http status code should be ok (200).")
            #expect(oAuthTokenResponseDto.accessToken.isEmpty == false, "Access token have to be returned.")
            #expect(oAuthTokenResponseDto.refreshToken == nil, "Refresh token should not be returned.")
        }
        
        @Test("Access token should be refreshed for correct refresh token")
        func accessTokenShouldBeRefreshedForCorrectRefreshToken() async throws {
            // Arrange.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601

            let user = try await application.createUser(userName: "czeslawgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)

            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let oAuthTokenResponseDto = try response.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Act.
            let refreshResponse = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=refresh_token&client_id=\(authDynamicClient.stringId() ?? "")&refresh_token=\(oAuthTokenResponseDto.refreshToken ?? "")".data(using: .ascii)!
            )
            
            let refreshOAuthTokenResponseDto = try refreshResponse.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(refreshResponse.status == .ok, "Response http status code should be ok (200).")
            #expect(refreshOAuthTokenResponseDto.accessToken.isEmpty == false, "Access token have to be returned.")
            #expect(refreshOAuthTokenResponseDto.refreshToken?.isEmpty == false, "Refresh token have to be returned.")
        }
        
        @Test("Access token should be refreshed for correct refresh token and private client")
        func accessTokenShouldBeRefreshedForCorrectRefreshTokenAndPrivateClient() async throws {
            // Arrange.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601

            let user = try await application.createUser(userName: "alexgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code],
                                                                                  userId: user.requireID())
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)

            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage&client_secret=\(authDynamicClient.clientSecret ?? "")".data(using: .ascii)!
            )
            
            let oAuthTokenResponseDto = try response.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Act.
            let refreshResponse = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=refresh_token&client_id=\(authDynamicClient.stringId() ?? "")&refresh_token=\(oAuthTokenResponseDto.refreshToken ?? "")&client_secret=\(authDynamicClient.clientSecret ?? "")".data(using: .ascii)!
            )
            
            let refreshOAuthTokenResponseDto = try refreshResponse.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(refreshResponse.status == .ok, "Response http status code should be ok (200).")
            #expect(refreshOAuthTokenResponseDto.accessToken.isEmpty == false, "Access token have to be returned.")
            #expect(refreshOAuthTokenResponseDto.refreshToken?.isEmpty == false, "Refresh token have to be returned.")
        }
        
        @Test("Invalid request when code not exists for authorization code grant type")
        func invalidRequestHaveToBeSpecifiedWhenCodeNotExistsForAuthorizationCodeGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "nikitagibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Code have to be specified for 'authorization_code' grant type.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when client id not exists for authorization code grant type")
        func invalidRequestHaveToBeSpecifiedWhenClientIdNotExistsForAuthorizationCodeGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "annagibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client id have to be specified for 'authorization_code' grant type.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when code is for different client id for authorization code grant type")
        func invalidRequestWhenCodeIsForDifferentClientIdForAuthorizationCodeGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "franiagibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=123&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client id mismatch.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when code not exists for authorization code grant type")
        func invalidRequestWhenCodeNotExistsForAuthorizationCodeGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "jozefagibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=123&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Code '123' is invalid.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when client not support grant type for authorization code grant type")
        func invalidRequestWhenClientNotSupportGrantTypeForAuthorizationCodeGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "mariagibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.clientCredentials],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client does not support 'authorization_code' grant type.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when code expired for authorization code grant type")
        func invalidRequestWhenCodeExporedForAuthorizationCodeGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "jolantagibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest, codeGeneratedAt: Date().addingTimeInterval(-120))
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Code '\(oAuthClientRequest.code ?? "")' expired (code is valid one minute).", "Correct error description should be send.")
        }
        
        @Test("Invalid request when redirect uri mismatched for authorization code grant type")
        func invalidRequestWhenRedirectUriMismatchedForAuthorizationCodeGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "weronikagibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/mismiatched".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Redirect URI mismatch.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when client secret not specified for private client for authorization code grant type")
        func invalidRequestWhenClientSecretNotSpecifiedForPrivateClientForAuthorizationCodeGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "romuldagibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client secret have to be specified if the client was issued a client secret.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when client secret not valid for private client for authorization code grant type")
        func invalidRequestWhenClientSecretNotValidForPrivateClientForAuthorizationCodeGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "renatagibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage&client_secret=939393".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client secret is invalid.", "Correct error description should be send.")
        }
        
        @Test("Access denied when user not authorized client for authorization code grant type")
        func invalidRequestWhenUserNotAuthorizedClientForAuthorizationCodeGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "aldonagibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .accessDenied, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "User not authorized the client.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when client secret is missing for client credentials grant type")
        func invalidRequestWhenClientSecretIsMissingForClientCredentialsGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "romangibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.clientCredentials],
                                                                                  responseTypes: [.code],
                                                                                  userId: user.requireID())

            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=client_credentials&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/vernissage&client_secret=".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client secret have to be specified for 'client_credentials' grant type.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when client id is missing for client credentials grant type")
        func invalidRequestWhenClientIdIsMissingForClientCredentialsGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "tobiaszgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.clientCredentials],
                                                                                  responseTypes: [.code],
                                                                                  userId: user.requireID())

            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=client_credentials&client_id=&redirect_uri=oauth-callback:/vernissage&client_secret=\(authDynamicClient.clientSecret ?? "")".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Correct client id have to be specified for 'client_credentials' grant type.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when wrong credentials has been specified for client credentials grant type")
        func invalidRequestWhenWrongCredentialsHasBeenSpecifiedForClientCredentialsGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "franekgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.clientCredentials],
                                                                                  responseTypes: [.code],
                                                                                  userId: user.requireID())

            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=client_credentials&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/vernissage&client_secret=123".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Wrong client credentials.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when grant type is not supported for client credentials grant type")
        func invalidRequestWhenGrantTypeIsNotSupportedForClientCredentialsGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "tomekgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.authorizationCode],
                                                                                  responseTypes: [.code],
                                                                                  userId: user.requireID())

            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=client_credentials&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/vernissage&client_secret=\(authDynamicClient.clientSecret ?? "")".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client does not support 'client_credentials' grant type.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when client is public for client credentials grant type")
        func invalidRequestWhenClientIsPublicForClientCredentialsGrantType() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "dawidgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.clientCredentials],
                                                                                  responseTypes: [.code])

            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=client_credentials&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/vernissage&client_secret=\(authDynamicClient.clientSecret ?? "")".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Cannot use 'client_credentials' grant type for public client.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when redirect uri mismatched for client credentials grant type")
        func invalidRequestWhenRedirectUriMismatchedForClientCredentialsGrantType() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wacekgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.clientCredentials],
                                                                                  responseTypes: [.code],
                                                                                  userId: user.requireID())

            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=client_credentials&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/mismatched&client_secret=\(authDynamicClient.clientSecret ?? "")".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthErrorDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Redirect URI mismatch.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when refresh token not specified for refresh token grant type")
        func invalidRequestWhenRefreshTokenNotSpecifiedForRefreshTokenGrantType() async throws {
            // Arrange.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601

            let user = try await application.createUser(userName: "erikgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)

            _ = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
                        
            // Act.
            let refreshResponse = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=refresh_token&client_id=\(authDynamicClient.stringId() ?? "")&refresh_token=".data(using: .ascii)!
            )
            
            let oAuthErrorDto = try refreshResponse.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(refreshResponse.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Refresh token have to be specified for 'refresh_token' grant type.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when client id not specified for refresh token grant type")
        func invalidRequestWhenClientIdNotSpecifiedForRefreshTokenGrantType() async throws {
            // Arrange.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601

            let user = try await application.createUser(userName: "pawelgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)

            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let oAuthTokenResponseDto = try response.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Act.
            let refreshResponse = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=refresh_token&client_id=&refresh_token=\(oAuthTokenResponseDto.refreshToken ?? "")".data(using: .ascii)!
            )
            
            let oAuthErrorDto = try refreshResponse.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(refreshResponse.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client id have to be specified for 'refresh_token' grant type.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when client id is invalid for refresh token grant type")
        func invalidRequestWhenClientIdIsInvalidForRefreshTokenGrantType() async throws {
            // Arrange.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601

            let user = try await application.createUser(userName: "piotrgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)

            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let oAuthTokenResponseDto = try response.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Act.
            let refreshResponse = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=refresh_token&client_id=123&refresh_token=\(oAuthTokenResponseDto.refreshToken ?? "")".data(using: .ascii)!
            )
            
            let oAuthErrorDto = try refreshResponse.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(refreshResponse.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client id is invalid.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when refresh token not supported for refresh token grant type")
        func invalidRequestWhenRefreshTokenNotSupportedForRefreshTokenGrantType() async throws {
            // Arrange.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601

            let user = try await application.createUser(userName: "rafalgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode],
                                                                                  responseTypes: [.code])
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)

            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage".data(using: .ascii)!
            )
            
            let oAuthTokenResponseDto = try response.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Act.
            let refreshResponse = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=refresh_token&client_id=\(authDynamicClient.stringId() ?? "")&refresh_token=\(oAuthTokenResponseDto.refreshToken ?? "")".data(using: .ascii)!
            )
            
            let oAuthErrorDto = try refreshResponse.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(refreshResponse.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client does not support 'refresh_token' grant type.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when client secret not speified for private client for refresh token grant type")
        func invalidRequestWhenClientSecretNotSpecifiedForProvateClientForRefreshTokenGrantType() async throws {
            // Arrange.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601

            let user = try await application.createUser(userName: "arturgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code],
                                                                                  userId: user.requireID())
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)

            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage&client_secret=\(authDynamicClient.clientSecret ?? "")".data(using: .ascii)!
            )
            
            let oAuthTokenResponseDto = try response.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Act.
            let refreshResponse = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=refresh_token&client_id=\(authDynamicClient.stringId() ?? "")&refresh_token=\(oAuthTokenResponseDto.refreshToken ?? "")".data(using: .ascii)!
            )
            
            let oAuthErrorDto = try refreshResponse.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(refreshResponse.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client secret have to be specified if the client was issued a client secret.", "Correct error description should be send.")
        }
        
        @Test("Invalid request when client secret invalid for private client for refresh token grant type")
        func invalidRequestWhenClientSecretInvalidForProvateClientForRefreshTokenGrantType() async throws {
            // Arrange.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601

            let user = try await application.createUser(userName: "grzegorzgibon")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  tokenEndpointAuthMethod: .clientSecretPost,
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code],
                                                                                  userId: user.requireID())
            
            let oAuthClientRequest = try await application.createOAuthClientRequest(authDynamicClientId: authDynamicClient.requireID(),
                                                                                    userId: user.requireID(),
                                                                                    csrfToken: String.createRandomString(length: 64),
                                                                                    redirectUri: "oauth-callback:/vernissage",
                                                                                    scope: "read write",
                                                                                    state: "state",
                                                                                    nonce: String.createRandomString(length: 32))
            
            try await application.genereteOAuthClientRequestCode(oAuthClientRequest: oAuthClientRequest)
            try await application.authorizeOAuthClientRequest(oAuthClientRequest: oAuthClientRequest)

            let response = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=authorization_code&client_id=\(authDynamicClient.stringId() ?? "")&code=\(oAuthClientRequest.code ?? "")&redirect_uri=oauth-callback:/vernissage&client_secret=\(authDynamicClient.clientSecret ?? "")".data(using: .ascii)!
            )
            
            let oAuthTokenResponseDto = try response.content.decode(OAuthTokenResponseDto.self, using: jsonDecoder)
            
            // Act.
            let refreshResponse = try await application.sendRequest(
                to: "/oauth/token",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "grant_type=refresh_token&client_id=\(authDynamicClient.stringId() ?? "")&refresh_token=\(oAuthTokenResponseDto.refreshToken ?? "")&client_secret=123".data(using: .ascii)!
            )
            
            let oAuthErrorDto = try refreshResponse.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(refreshResponse.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthErrorDto.error == .invalidRequest, "Invalid request should be send as error.")
            #expect(oAuthErrorDto.errorDescription == "Client secret is invalid.", "Correct error description should be send.")
        }
    }
}
