//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class LocationsReadActionTests: CustomTestCase {
    
    func testLocationShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        _ = try await User.create(userName: "wictortequ")
        let newLocation = try await Location.create(name: "Rzeszotary")

        // Act.
        let location = try SharedApplication.application().getResponse(
            as: .user(userName: "wictortequ", password: "p@ssword"),
            to: "/locations/\(newLocation.requireID())",
            method: .GET,
            decodeTo: LocationDto.self
        )

        // Assert.
        XCTAssertNotNil(location, "Location should be added.")
        XCTAssertEqual(newLocation.name, location.name, "Locations name should be correct.")
    }
    
    func testLocationShouldNotBeReturnedForUnauthorizedUser() async throws {
        // Arrange.
        let newLocation = try await Location.create(name: "Polkowice")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/locations/\(newLocation.requireID())",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

