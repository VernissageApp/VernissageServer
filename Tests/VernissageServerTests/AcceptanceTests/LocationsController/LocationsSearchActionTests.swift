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

extension LocationsControllerTests {
    
    @Suite("GET /", .serialized, .tags(.locations))
    struct LocationsSearchActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Locations list should be returned for authorized user")
        func locationsListShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "wictorulos")
            _ = try await application.createLocation(name: "Legnica")
            
            // Act.
            let locations = try application.getResponse(
                as: .user(userName: "wictorulos", password: "p@ssword"),
                to: "/locations?code=PL&query=legnica",
                method: .GET,
                decodeTo: [LocationDto].self
            )
            
            // Assert.
            #expect(locations.count > 0, "Locations list should be returned.")
        }
        
        @Test("Locations list should not be returned for unauthorized user")
        func locationsListShouldNotBeReturnedForUnauthorizedUser() async throws {
            
            // Act.
            let response = try application.sendRequest(
                to: "/locations?code=PL&query=legnica",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
