//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("AuthenticationClients (POST /auth-clients)", .serialized, .tags(.authClients))
    struct AuthenticationClientsCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Auth client should be created by super user")
        func authClientShouldBeCreatedBySuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "borisriq")
            try await application.attach(user: user, role: Role.administrator)
            let authClientDto = AuthClientDto(type: .microsoft, name: "Microsoft", uri: "microsoft", tenantId: "123", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "<svg />")
            
            // Act.
            let createdAuthDtoDto = try await application.getResponse(
                as: .user(userName: "borisriq", password: "p@ssword"),
                to: "/auth-clients",
                method: .POST,
                data: authClientDto,
                decodeTo: AuthClientDto.self
            )
            
            // Assert.
            #expect(createdAuthDtoDto.id != nil, "Auth client wasn't created.")
        }
        
        @Test("Created status code should be returned after creating new auth client")
        func createdStatusCodeShouldBeReturnedAfterCreatingNewAuthClient() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "martinriq")
            try await application.attach(user: user, role: Role.administrator)
            let authClientDto = AuthClientDto(type: .google, name: "Google", uri: "google", tenantId: "123", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "<svg />")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "martinriq", password: "p@ssword"),
                to: "/auth-clients",
                method: .POST,
                body: authClientDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
        }
        
        @Test("Header location should be returned after creating new auth client")
        func headerLocationShouldBeReturnedAfterCreatingNewAuthClient() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "victoreiq")
            try await application.attach(user: user, role: Role.administrator)
            let authClientDto = AuthClientDto(type: .apple, name: "Apple", uri: "apple", tenantId: "123", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "<svg />")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "victoreiq", password: "p@ssword"),
                to: "/auth-clients",
                method: .POST,
                body: authClientDto
            )
            
            // Assert.
            let location = response.headers.first(name: .location)
            let authClient = try response.content.decode(AuthClientDto.self)
            #expect(location == "/auth-clients/\(authClient.id ?? "")", "Location header should contains created role id.")
        }
        
        @Test("Auth client should not be created if user is not super user")
        func authClientShouldNotBeCreatedIfUserIsNotSuperUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "robincriq")
            let authClientDto = AuthClientDto(type: .apple, name: "Apple", uri: "apple-01", tenantId: "123", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "<svg />")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "robincriq", password: "p@ssword"),
                to: "/auth-clients",
                method: .POST,
                body: authClientDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Auth client should not be created if auth client with same uri exists")
        func authClientShouldNotBeCreatedIfAuthClientWithSameUriExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "erikriq")
            try await application.attach(user: user, role: Role.administrator)
            _ = try await application.createAuthClient(type: .apple, name: "Apple", uri: "apple-with-uri", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            
            let authClientDto = AuthClientDto(type: .apple, name: "Apple", uri: "apple-with-uri", tenantId: "123", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "<svg />")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "erikriq", password: "p@ssword"),
                to: "/auth-clients",
                method: .POST,
                data: authClientDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "authClientWithUriExists", "Error code should be equal 'authClientWithUriExists'.")
        }
    }
}
