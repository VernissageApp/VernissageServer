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
    
    @Suite("Countries (GET /countries)", .serialized, .tags(.countries))
    struct CountriesListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Countries list should be returned for authorized user`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "wictorpink")
            
            // Act.
            let countries = try await application.getResponse(
                as: .user(userName: "wictorpink", password: "p@ssword"),
                to: "/countries",
                method: .GET,
                decodeTo: [CountryDto].self
            )
            
            // Assert.
            #expect(countries.count > 0, "Countries list should be returned.")
        }
        
        @Test
        func `Countries list should not be returned for unauthorized user`() async throws {
            
            // Act.
            let response = try await application.sendRequest(
                to: "/countries",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
