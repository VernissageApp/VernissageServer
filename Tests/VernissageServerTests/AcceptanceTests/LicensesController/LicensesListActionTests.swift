//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class LicensesListActionTests: CustomTestCase {
    
    func testLicensesListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        _ = try await User.create(userName: "wictorliqus")

        // Act.
        let licenses = try SharedApplication.application().getResponse(
            as: .user(userName: "wictorliqus", password: "p@ssword"),
            to: "/licenses",
            method: .GET,
            decodeTo: [LicenseDto].self
        )

        // Assert.
        XCTAssert(licenses.count > 0, "Licenses list should be returned.")
    }
    
    func testLicensesListShouldNotBeReturnedForUnauthorizedUser() async throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/licenses",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

