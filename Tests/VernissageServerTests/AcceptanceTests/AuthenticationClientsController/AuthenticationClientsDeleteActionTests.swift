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

extension AuthenticationClientsControllerTests {
    
    @Suite("DELETE /:id", .serialized, .tags(.authClients))
    struct AuthenticationClientsDeleteActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Auth client should be deleted if auth client exists and user is super user")
        func authClientShouldBeDeletedIfAuthClientExistsAndUserIsSuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "alinayork")
            try await application.attach(user: user, role: Role.administrator)
            let authClientToDelete = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-to-delete-01", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "alinayork", password: "p@ssword"),
                to: "/auth-clients/\(authClientToDelete.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let authClient = try? await application.getAuthClient(uri: "client-to-delete-01")
            #expect(authClient == nil, "Auth client should be deleted.")
        }
        
        @Test("Auth client should not be deleted if auth client exists but user is not super user")
        func authClientShouldNotBeDeletedIfAuthClientExistsButUserIsNotSuperUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "robinyork")
            let authClientToDelete = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-to-delete-02", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "robinyork", password: "p@ssword"),
                to: "/auth-clients/\(authClientToDelete.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be bad request (400).")
        }
        
        @Test("Correct status code should be returned if auth client not exists")
        func correctStatusCodeShouldBeReturnedIfAuthClientNotExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "wikiyork")
            try await application.attach(user: user, role: Role.administrator)
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "wikiyork", password: "p@ssword"),
                to: "/auth-clients/542863",
                method: .DELETE
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
