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
    
    @Suite("Locations (GET /locations)", .serialized, .tags(.locations))
    struct LocationsSearchActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Locations list should be returned for authorized user`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "wictorulos")
            _ = try await application.createLocation(name: "Legnica")
            
            // Act.
            let locations = try await application.getResponse(
                as: .user(userName: "wictorulos", password: "p@ssword"),
                to: "/locations?code=PL&query=legnica",
                method: .GET,
                decodeTo: [LocationDto].self
            )
            
            // Assert.
            #expect(locations.count > 0, "Locations list should be returned.")
        }
        
        @Test
        func `Locations list should not be returned for unauthorized user`() async throws {
            
            // Act.
            let response = try await application.sendRequest(
                to: "/locations?code=PL&query=legnica",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
