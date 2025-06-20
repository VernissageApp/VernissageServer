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
    
    @Suite("AuthenticationClients (GET /auth-clients/:id)", .serialized, .tags(.authClients))
    struct AuthenticationClientsReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Auth client should be returned for super user")
        func authClientShouldBeReturnedForSuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinwath")
            try await application.attach(user: user, role: Role.administrator)
            let authClient = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-for-read-01", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            
            // Act.
            let authClientDto = try await application.getResponse(
                as: .user(userName: "robinwath", password: "p@ssword"),
                to: "/auth-clients/\(authClient.stringId() ?? "")",
                method: .GET,
                decodeTo: AuthClientDto.self
            )
            
            // Assert.
            #expect(authClientDto.id == authClient.stringId(), "Auth client id should be correct.")
            #expect(authClientDto.name == authClient.name, "Auth client name should be correct.")
            #expect(authClientDto.uri == authClient.uri, "Auth client uri should be correct.")
            #expect(authClientDto.callbackUrl == authClient.callbackUrl, "Auth client callbackUrl should be correct.")
            #expect(authClientDto.clientId == authClient.clientId, "Auth client clientId should be correct.")
            #expect(authClientDto.clientSecret == "", "Auth client secret should be empty.")
        }
        
        @Test("Auth client should be returned if user is not super user")
        func authClientShouldBeReturnedIfUserIsNotSuperUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickywath")
            let authClient = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-for-read-02", tenantId: "tenantId", clientId: "clientId", clientSecret: "rickywath", callbackUrl: "callback", svgIcon: "svg")
            
            // Act.
            let authClientDto = try await application.getResponse(
                as: .user(userName: "robinwath", password: "p@ssword"),
                to: "/auth-clients/\(authClient.stringId() ?? "")",
                method: .GET,
                decodeTo: AuthClientDto.self
            )
            
            // Assert.
            #expect(authClientDto.id == authClient.stringId(), "Auth client id should be correct.")
            #expect(authClientDto.name == authClient.name, "Auth client name should be correct.")
            #expect(authClientDto.uri == authClient.uri, "Auth client uri should be correct.")
            #expect(authClientDto.callbackUrl == authClient.callbackUrl, "Auth client callbackUrl should be correct.")
            #expect(authClientDto.clientId == authClient.clientId, "Auth client clientId should be correct.")
            #expect(authClientDto.clientSecret == "", "Auth client secret should be empty.")
        }
        
        @Test("Correct status code should be returned if auth client not exists")
        func correctStatusCodeShouldBeReturnedIdAuthClientNotExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "tedwarth")
            try await application.attach(user: user, role: Role.administrator)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "tedwarth", password: "p@ssword"),
                to: "/auth-clients/76532",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
