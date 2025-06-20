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
    
    @Suite("AuthenticationClients (GET /auth-clients)", .serialized, .tags(.authClients))
    struct AuthenticationClientsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of auth clients should be returned for super user")
        func listOfAuthClientsShouldBeReturnedForSuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robintorx")
            try await application.attach(user: user, role: Role.administrator)
            _ = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-for-list-01", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            _ = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-for-list-02", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            
            // Act.
            let authClients = try await application.getResponse(
                as: .user(userName: "robintorx", password: "p@ssword"),
                to: "/auth-clients",
                method: .GET,
                decodeTo: [AuthClientDto].self
            )
            
            // Assert.
            #expect(authClients.count > 0, "A list of auth clients was not returned.")
        }
        
        @Test("List of auth clients should be returned for super user")
        func listOfAuthClientsShouldBeReturnedForNotSuperUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "wictortorx")
            _ = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-for-list-03", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            _ = try await application.createAuthClient(type: .apple, name: "Apple", uri: "client-for-list-04", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
            
            // Act.
            let authClients = try await application.getResponse(
                as: .user(userName: "wictortorx", password: "p@ssword"),
                to: "/auth-clients",
                method: .GET,
                decodeTo: [AuthClientDto].self
            )
            
            // Assert.
            #expect(authClients.count > 0, "A list of auth clients was not returned.")
        }
    }
}
