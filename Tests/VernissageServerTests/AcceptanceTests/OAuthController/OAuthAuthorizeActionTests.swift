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
    
    @Suite("OAuth (GET /oauth/authorize?client_id=...&redirect_uri=...)", .serialized, .tags(.oAuth))
    struct OAuthAuthorizeActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
                
        @Test
        func `Authorization web page should be returned for already authorized user`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "wictorsigned")
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "wictorsigned", password: "p@ssword"),
                to: "/oauth/authorize?response_type=code&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/vernissage&scope=read%20write&state=jht8jbnd",
                method: .GET
            )

            // Assert.
            #expect(response.status == .ok, "Response http status code should be ok (200).")
            #expect(response.body.string.contains("Authorize application to Vernissage"), "Returned body should contains html code.")
            #expect(response.body.string.contains("The application <strong>VernissageTestClient</strong> would like permission to access your account <strong>@wictorsigned</strong>."), "Returned body should contains html code.")
        }
        
        @Test
        func `Redirection should be returned for not authorized user`() async throws {
            // Arrange.
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            // Act.
            let response = try await application.sendRequest(
                to: "/oauth/authorize?response_type=code&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/vernissage&scope=read%20write&state=jht8jbnd",
                method: .GET
            )

            // Assert.
            #expect(response.status == .seeOther, "Response http status code should be see other (303).")
            #expect(response.headers.first(name: "Location")?.starts(with: "/login?state=jht8jbnd&client_id=\(authDynamicClient.stringId() ?? "")&scope=read write&redirect_uri=oauth-callback:/vernissage&nonce=") == true, "Locations header should be returned.")
        }
        
        @Test
        func `Invalid request error should be returned for incorrect client id`() async throws {
            // Act.
            let response = try await application.getResponse(
                to: "/oauth/authorize?response_type=code&client_id=123&redirect_uri=oauth-callback:/vernissage&scope=read%20write&state=jht8jbnd",
                method: .GET,
                decodeTo: OAuthErrorDto.self
            )

            // Assert.
            #expect(response.error == .invalidRequest, "Invalid request error code should be returned.")
            #expect(response.errorDescription == "Client `123` is not registered.", "Incorrect client error message should be returned.")
        }
        
        @Test
        func `Invalid request error should be returned for not registered redirect uri`() async throws {
            // Arrange.
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            // Act.
            let response = try await application.getResponse(
                to: "/oauth/authorize?response_type=code&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/notexits&scope=read%20write&state=jht8jbnd",
                method: .GET,
                decodeTo: OAuthErrorDto.self
            )

            // Assert.
            #expect(response.error == .invalidRequest, "Invalid request error code should be returned.")
            #expect(response.errorDescription == "Redirect URI 'oauth-callback:/notexits' has not been registered in the client.", "Incorrect redirect uri error message should be returned.")
        }
        
        @Test
        func `Invalid request error should be returned for not registered response type`() async throws {
            // Arrange.
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            // Act.
            let response = try await application.getResponse(
                to: "/oauth/authorize?response_type=token&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/vernissage&scope=read%20write&state=jht8jbnd",
                method: .GET,
                decodeTo: OAuthErrorDto.self
            )

            // Assert.
            #expect(response.error == .invalidRequest, "Invalid request error code should be returned.")
            #expect(response.errorDescription == "Response type 'token' has not been registered in the client.", "Incorrect redirect uri error message should be returned.")
        }
        
        @Test
        func `Invalid scope error should be returned for not registered scope`() async throws {
            // Arrange.
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  scope: "read",
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            // Act.
            let response = try await application.getResponse(
                to: "/oauth/authorize?response_type=code&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/vernissage&scope=read%20write&state=jht8jbnd",
                method: .GET,
                decodeTo: OAuthErrorDto.self
            )

            // Assert.
            #expect(response.error == .invalidScope, "Invalid scope error code should be returned.")
            #expect(response.errorDescription == "Scope 'write' has not been registered in the client.", "Incorrect redirect uri error message should be returned.")
        }
        
        @Test
        func `Invalid scope error should be returned for not supported scope`() async throws {
            // Arrange.
            let authDynamicClient = try await application.createAuthDynamicClient(clientName: "VernissageTestClient",
                                                                                  redirectUris: ["oauth-callback:/vernissage"],
                                                                                  grantTypes: [.authorizationCode, .refreshToken],
                                                                                  responseTypes: [.code])
            
            // Act.
            let response = try await application.getResponse(
                to: "/oauth/authorize?response_type=code&client_id=\(authDynamicClient.stringId() ?? "")&redirect_uri=oauth-callback:/vernissage&scope=delete%20write&state=jht8jbnd",
                method: .GET,
                decodeTo: OAuthErrorDto.self
            )

            // Assert.
            #expect(response.error == .invalidScope, "Invalid scope error code should be returned.")
            #expect(response.errorDescription == "Scope 'delete' is not supported.", "Incorrect redirect uri error message should be returned.")
        }
    }
}
