//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class WebfingerReadActionTests: XCTestCase {
    
    func testWebfingerShouldBeReturnedForExistingActor() throws {
        
        // Arrange.
        _ = try User.create(userName: "ronaldtrix")
        
        // Act.
        let webfingerDto = try SharedApplication.application().getResponse(
            to: "/.well-known/webfinger?resource=acct:ronaldtrix@host.com",
            decodeTo: WebfingerDto.self
        )
        
        // Assert.
        XCTAssertEqual(webfingerDto.subject, "acct:ronaldtrix@host.com", "Property 'subject' should be equal.")
        XCTAssertNotNil(webfingerDto.aliases.first(where: { $0 == "http://localhost:8000/ronaldtrix" }), "Property 'alias' doesn't contains alias")
        XCTAssertNotNil(webfingerDto.aliases.first(where: { $0 == "http://localhost:8000/actors/ronaldtrix" }), "Property 'alias' doesn't contains alias")
        XCTAssertEqual(
            webfingerDto.links.first(where: { $0.rel == "self"})?.href,
            "http://localhost:8000/actors/ronaldtrix",
            "Property 'links' should contains correct 'self' item.")
        XCTAssertEqual(
            webfingerDto.links.first(where: { $0.rel == "http://webfinger.net/rel/profile-page"})?.href,
            "http://localhost:8000/ronaldtrix",
            "Property 'links' should contains correct 'profile-page' item.")
    }
    
    func testWebfingerShouldNotBeReturnedForNotExistingActor() throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/.well-known/webfinger?resource=acct:unknown@host.com", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}

