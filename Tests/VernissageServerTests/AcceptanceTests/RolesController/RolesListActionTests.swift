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
    
    @Suite("Roles (GET /roles)", .serialized, .tags(.roles))
    struct RolesListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of roles should be returned for super user")
        func listOfRolesShouldBeReturnedForSuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinorange")
            try await application.attach(user: user, role: Role.administrator)
            
            // Act.
            let roles = try await application.getResponse(
                as: .user(userName: "robinorange", password: "p@ssword"),
                to: "/roles",
                method: .GET,
                decodeTo: [RoleDto].self
            )
            
            // Assert.
            #expect(roles.count > 0, "Role list was returned.")
        }
        
        @Test("List of roles should not be returned for not super user")
        func listOfRolesShouldNotBeReturnedForNotSuperUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "wictororange")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "wictororange", password: "p@ssword"),
                to: "/roles",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be bad request (400).")
        }
    }
}
