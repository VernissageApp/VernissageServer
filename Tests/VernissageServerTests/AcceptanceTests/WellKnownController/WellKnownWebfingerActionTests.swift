//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class WellKnownWebfingerActionTests: CustomTestCase {
    
    func testWebfingerShouldBeReturnedForExistingActor() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "ronaldtrix")
        
        // Act.
        let webfingerDto = try SharedApplication.application().getResponse(
            to: "/.well-known/webfinger?resource=acct:ronaldtrix@localhost:8080",
            version: .none,
            decodeTo: WebfingerDto.self
        )
        
        // Assert.
        XCTAssertEqual(webfingerDto.subject, "acct:ronaldtrix@localhost:8080", "Property 'subject' should be equal.")
        XCTAssertNotNil(webfingerDto.aliases?.first(where: { $0 == "http://localhost:8080/@ronaldtrix" }), "Property 'alias' doesn't contains alias")
        XCTAssertNotNil(webfingerDto.aliases?.first(where: { $0 == "http://localhost:8080/actors/ronaldtrix" }), "Property 'alias' doesn't contains alias")
        XCTAssertEqual(
            webfingerDto.links.first(where: { $0.rel == "self"})?.href,
            "http://localhost:8080/actors/ronaldtrix",
            "Property 'links' should contains correct 'self' item.")
        XCTAssertEqual(
            webfingerDto.links.first(where: { $0.rel == "http://webfinger.net/rel/profile-page"})?.href,
            "http://localhost:8080/@ronaldtrix",
            "Property 'links' should contains correct 'profile-page' item.")
    }
    
    func testWebfingerShouldReturnJrdJsonContentTypeHeader() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "tobintrix")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/.well-known/webfinger?resource=acct:tobintrix@localhost:8080",
            version: .none,
            method: .GET
        )
        
        // Assert.
        XCTAssertEqual(response.headers.contentType?.description, "application/jrd+json; charset=utf-8", "Returned content type should be application/jrd+json.")
    }
    
    func testWebfingerShouldNotBeReturnedForNotExistingActor() throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/.well-known/webfinger?resource=acct:unknown@localhost:8080",
                                                                       version: .none,
                                                                       method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}

