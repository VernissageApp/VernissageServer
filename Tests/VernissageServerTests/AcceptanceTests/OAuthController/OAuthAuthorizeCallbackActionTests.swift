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
    
    @Suite("OAuth (POST /oauth/authorize)", .serialized, .tags(.oAuth))
    struct OAuthAuthorizeCallbackActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Redirection with code should be returned for correct authorization")
        func redirectionWithCodeShouldBeReturnedForCorrectAuthorization() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorbonny")
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
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "wictorbonny", password: "p@ssword"),
                to: "/oauth/authorize",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "id=\(oAuthClientRequest.stringId() ?? "")&csrfToken=\(oAuthClientRequest.csrfToken)&state=state".data(using: .ascii)!
            )
            
            // Assert.
            #expect(response.status == .seeOther, "Response http status code should be see other (303).")
            #expect(response.headers.first(name: "Location")?.starts(with: "oauth-callback:/vernissage?code=") == true, "Location should be set to redirect uri with code.")
        }
        
        @Test("Invalid request should be returned for incorrect request id")
        func invalidRequestShouldBeRetruendForIncorrectRequestId() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "annabonny")
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
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "annabonny", password: "p@ssword"),
                to: "/oauth/authorize",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "id=aaa&csrfToken=\(oAuthClientRequest.csrfToken)&state=state".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthTokenResponseDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthTokenResponseDto.error == .invalidRequest, "Invalid request should be returned in the response body.")
            #expect(oAuthTokenResponseDto.errorDescription == "Client request id 'aaa' cannot be parsed to correct integer.", "Error message should be returned in the response body.")
        }
        
        @Test("Invalid request should be returned for unknown request id")
        func invalidRequestShouldBeRetruendForUnknownRequestId() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "markbonny")
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
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "markbonny", password: "p@ssword"),
                to: "/oauth/authorize",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "id=123&csrfToken=\(oAuthClientRequest.csrfToken)&state=state".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthTokenResponseDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthTokenResponseDto.error == .invalidRequest, "Invalid request should be returned in the response body.")
            #expect(oAuthTokenResponseDto.errorDescription == "Client request '123' not exists.", "Error message should be returned in the response body.")
        }
        
        @Test("Invalid request should be returned for mismatched CSRF")
        func invalidRequestShouldBeRetruendFormismatchedCsrf() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "justabonny")
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
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "justabonny", password: "p@ssword"),
                to: "/oauth/authorize",
                method: .POST,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                body: "id=\(oAuthClientRequest.stringId() ?? "")&csrfToken=aaa&state=state".data(using: .ascii)!
            )
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .customISO8601
            let oAuthTokenResponseDto = try response.content.decode(OAuthErrorDto.self, using: jsonDecoder)
            
            // Assert.
            #expect(response.status == .badRequest, "Response http status code should be bad request (400).")
            #expect(oAuthTokenResponseDto.error == .invalidRequest, "Invalid request should be returned in the response body.")
            #expect(oAuthTokenResponseDto.errorDescription == "CSRF token 'aaa' mismatch.", "Error message should be returned in the response body.")
        }
    }
}
