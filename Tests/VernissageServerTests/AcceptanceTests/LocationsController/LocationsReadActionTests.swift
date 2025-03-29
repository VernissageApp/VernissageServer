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
    
    @Suite("Locations (GET /locations/:id)", .serialized, .tags(.locations))
    struct LocationsReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Location should be returned for authorized user")
        func locationShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "wictortequ")
            let newLocation = try await application.createLocation(name: "Rzeszotary")
            
            // Act.
            let location = try await application.getResponse(
                as: .user(userName: "wictortequ", password: "p@ssword"),
                to: "/locations/\(newLocation.requireID())",
                method: .GET,
                decodeTo: LocationDto.self
            )
            
            // Assert.
            #expect(location != nil, "Location should be added.")
            #expect(newLocation.name == location.name, "Locations name should be correct.")
        }
        
        @Test("Location should not be returned for unauthorize uUser")
        func locationShouldNotBeReturnedForUnauthorizedUser() async throws {
            // Arrange.
            let newLocation = try await application.createLocation(name: "Polkowice")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/locations/\(newLocation.requireID())",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
