//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class LocationsSearchActionTests: CustomTestCase {
    
    func testLocationsListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        _ = try await User.create(userName: "wictorulos")
        _ = try await Location.create(name: "Legnica")

        // Act.
        let locations = try SharedApplication.application().getResponse(
            as: .user(userName: "wictorulos", password: "p@ssword"),
            to: "/locations?code=PL&query=legnica",
            method: .GET,
            decodeTo: [LocationDto].self
        )

        // Assert.
        XCTAssert(locations.count > 0, "Locations list should be returned.")
    }
    
    func testLocationsListShouldNotBeReturnedForUnauthorizedUser() async throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/locations?code=PL&query=legnica",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

