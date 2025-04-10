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
    
    @Suite("Licenses (GET /licenses)", .serialized, .tags(.licenses))
    struct LicensesListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Licenses list should be returned for authorized user")
        func licensesListShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "wictorliqus")
            
            // Act.
            let licenses = try await application.getResponse(
                as: .user(userName: "wictorliqus", password: "p@ssword"),
                to: "/licenses",
                method: .GET,
                decodeTo: [LicenseDto].self
            )
            
            // Assert.
            #expect(licenses.count > 0, "Licenses list should be returned.")
        }
        
        @Test("Licenses list should not be returned for unauthorized user")
        func licensesListShouldNotBeReturnedForUnauthorizedUser() async throws {
            
            // Act.
            let response = try await application.sendRequest(
                to: "/licenses",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
