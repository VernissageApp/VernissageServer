//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
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
    
    func testCategoriesListShouldBeReturnedForOnlyUsedParameter() async throws {
        // Arrange.
        let user = try await User.create(userName: "rockytobim")
        let category = try await Category.get(name: "Abstract")!
        let (_, attachments) = try await Status.createStatuses(user: user, notePrefix: "Note", categoryId: category.stringId(), amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }

        // Act.
        let categories = try SharedApplication.application().getResponse(
            as: .user(userName: "rockytobim", password: "p@ssword"),
            to: "/categories?onlyUsed=true",
            method: .GET,
            decodeTo: [CategoryDto].self
        )

        // Assert.
        XCTAssert(categories.count > 0, "Categories list should be returned.")
    }
    
    func testCategoriesListShouldNotBeReturnedForUnauthorizedUserWhenCategoriesAreDisabled() async throws {
        // Arrange.
        try await Setting.update(key: .showCategoriesForAnonymous, value: .boolean(false))
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/categories",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testCategoriesListShouldBeReturnedForUnauthorizedUserWhenCategoriesAreEnabled() async throws {
        // Arrange.
        try await Setting.update(key: .showCategoriesForAnonymous, value: .boolean(true))
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/categories",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }
}

