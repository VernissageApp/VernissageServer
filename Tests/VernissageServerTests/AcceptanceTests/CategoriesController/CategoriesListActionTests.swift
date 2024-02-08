//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class CategoriesListActionTests: CustomTestCase {
    
    func testCategoriesListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        _ = try await User.create(userName: "wictortobim")

        // Act.
        let categories = try SharedApplication.application().getResponse(
            as: .user(userName: "wictortobim", password: "p@ssword"),
            to: "/categories",
            method: .GET,
            decodeTo: [CategoryDto].self
        )

        // Assert.
        XCTAssert(categories.count > 0, "Categories list should be returned.")
    }
    
    func testCategoriesListShouldNotBeReturnedForUnauthorizedUser() async throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/categories",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

