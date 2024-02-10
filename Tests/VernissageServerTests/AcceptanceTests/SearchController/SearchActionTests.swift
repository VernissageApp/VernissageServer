//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class SearchActionTests: CustomTestCase {
    
    func testSearchResultShouldBeReturnedWhenLocalAccountHasBeenSpecidfied() async throws {
        // Arrange.
        _ = try await User.create(userName: "trondfinder")
        
        // Act.
        let searchResultDto = try SharedApplication.application().getResponse(
            as: .user(userName: "trondfinder", password: "p@ssword"),
            to: "/search?query=admin",
            version: .v1,
            decodeTo: SearchResultDto.self
        )
        
        // Assert.
        XCTAssertNotNil(searchResultDto.users, "Users should be returned.")
        XCTAssertTrue((searchResultDto.users?.count ?? 0) > 0, "At least one user should be returned by the search.")
        XCTAssertNotNil(searchResultDto.users?.first(where: { $0.userName == "admin" }), "Admin account should be returned.")
    }
    
    func testSearchResultShouldBeReturnedWhenLocalAccountHasBeenSpecidfiedWithHostname() async throws {
        // Arrange.
        _ = try await User.create(userName: "karolfinder")
        
        // Act.
        let searchResultDto = try SharedApplication.application().getResponse(
            as: .user(userName: "karolfinder", password: "p@ssword"),
            to: "/search?query=admin@localhost",
            version: .v1,
            decodeTo: SearchResultDto.self
        )
        
        // Assert.
        XCTAssertNotNil(searchResultDto.users, "Users should be returned.")
        XCTAssertTrue((searchResultDto.users?.count ?? 0) > 0, "At least one user should be returned by the search.")
        XCTAssertNotNil(searchResultDto.users?.first(where: { $0.userName == "admin" }), "Admin account should be returned.")
    }
    
    func testEmptySearchResultShouldBeReturnedWhenLocalAccountHasNotFound() async throws {
        // Arrange.
        _ = try await User.create(userName: "ronaldfinder")
        
        // Act.
        let searchResultDto = try SharedApplication.application().getResponse(
            as: .user(userName: "ronaldfinder", password: "p@ssword"),
            to: "/search?query=notfounded",
            version: .v1,
            decodeTo: SearchResultDto.self
        )
        
        // Assert.
        XCTAssertNotNil(searchResultDto.users, "Users should be returned.")
        XCTAssertTrue((searchResultDto.users?.count ?? 0) == 0, "Empty list should be returned.")
    }

    func testSearchResultsShouldNotBeReturnedWhenQueryIsNotSpecified() async throws {
        // Arrange.
        _ = try await User.create(userName: "vikifinder")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "vikifinder", password: "p@ssword"),
            to: "/search",
            method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
    }
    
    func testSearchResultsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/search?query=admin", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

