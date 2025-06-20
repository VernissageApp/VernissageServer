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
    
    @Suite("AuthenticationClients (PUT /auth-clients/:id)", .serialized, .tags(.authClients))
    struct AuthenticationClientsUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Correct auth client should be updated by super user")
        func correctAuthClientShouldBeUpdatedBySuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "brucevoos")
            try await application.attach(user: user, role: Role.administrator)
            let authClient = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-for-update-01", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            let authClientToUpdate = AuthClientDto(type: .microsoft, name: "Microsoft", uri: "client-for-update-01", tenantId: "123", clientId: "clientId", clientSecret: "secret123", callbackUrl: "callback123", svgIcon: "<svg />")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "brucevoos", password: "p@ssword"),
                to: "/auth-clients/\(authClient.stringId() ?? "")",
                method: .PUT,
                body: authClientToUpdate
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            guard let updatedAuthClient = try? await application.getAuthClient(uri: "client-for-update-01") else {
                #expect(Bool(false), "Auth client was not found")
                return
            }
            
            #expect(updatedAuthClient.id == authClient.id, "Auth client id should be correct.")
            #expect(updatedAuthClient.name == authClientToUpdate.name, "Auth client name should be correct.")
            #expect(updatedAuthClient.uri == authClientToUpdate.uri, "Auth client uri should be correct.")
            #expect(updatedAuthClient.callbackUrl == authClientToUpdate.callbackUrl, "Auth client callbackUrl should be correct.")
            #expect(updatedAuthClient.clientId == authClientToUpdate.clientId, "Auth client clientId should be correct.")
            #expect(updatedAuthClient.clientSecret == authClientToUpdate.clientSecret, "Auth client secret should be correct.")
        }
        
        @Test("Auth client should not be updated if user is not super user")
        func authClientShouldNotBeUpdatedIfUserIsNotSuperUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "georgevoos")
            let authClient = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-for-update-02", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            let authClientToUpdate = AuthClientDto(type: .microsoft, name: "Microsoft", uri: "client-for-update-02", tenantId: "123", clientId: "clientId", clientSecret: "secret123", callbackUrl: "callback123", svgIcon: "<svg />")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "georgevoos", password: "p@ssword"),
                to: "/auth-clients/\(authClient.stringId() ?? "")",
                method: .PUT,
                body: authClientToUpdate
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Auth client should not be updated if auth client with same code exists")
        func authClientShouldNotBeUpdatedIfAuthClientWithSameCodeExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "samvoos")
            try await application.attach(user: user, role: Role.administrator)
            _ = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-for-update-03", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            let authClient02 = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-for-update-04", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            let authClientToUpdate = AuthClientDto(type: .microsoft, name: "Microsoft", uri: "client-for-update-03", tenantId: "123", clientId: "clientId", clientSecret: "secret123", callbackUrl: "callback123", svgIcon: "<svg />")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "samvoos", password: "p@ssword"),
                to: "/auth-clients/\(authClient02.stringId() ?? "")",
                method: .PUT,
                data: authClientToUpdate
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "authClientWithUriExists", "Error code should be equal 'roleWithCodeExists'.")
        }
    }
}
