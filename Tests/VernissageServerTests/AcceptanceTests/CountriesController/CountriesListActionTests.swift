//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class CountriesListActionTests: CustomTestCase {
    
    func testCountriesListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        _ = try await User.create(userName: "wictorpink")

        // Act.
        let countries = try SharedApplication.application().getResponse(
            as: .user(userName: "wictorpink", password: "p@ssword"),
            to: "/countries",
            method: .GET,
            decodeTo: [CountryDto].self
        )

        // Assert.
        XCTAssert(countries.count > 0, "Countries list should be returned.")
    }
    
    func testCountriesListShouldNotBeReturnedForUnauthorizedUser() async throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/countries",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

