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

@Suite("GET /", .serialized, .tags(.countries))
struct CountriesListActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Countries list should be returned for authorized user")
    func countriesListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        _ = try await application.createUser(userName: "wictorpink")

        // Act.
        let countries = try application.getResponse(
            as: .user(userName: "wictorpink", password: "p@ssword"),
            to: "/countries",
            method: .GET,
            decodeTo: [CountryDto].self
        )

        // Assert.
        #expect(countries.count > 0, "Countries list should be returned.")
    }
    
    @Test("Countries list should not be returned for unauthorized user")
    func countriesListShouldNotBeReturnedForUnauthorizedUser() async throws {

        // Act.
        let response = try application.sendRequest(
            to: "/countries",
            method: .GET
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

