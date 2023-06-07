//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubReadActionTests: XCTestCase {
    
    func testActorProfileShouldBeReturnedForExistingActor() throws {
        
        // Arrange.
        _ = try User.create(userName: "tronddedal")
        
        // Act.
        let personDto = try SharedApplication.application().getResponse(
            to: "/actors/tronddedal",
            version: .none,
            decodeTo: PersonDto.self
        )
        
        // Assert.
        XCTAssertEqual(personDto.id, "http://localhost:8000/actors/tronddedal", "Property 'id' is not valid.")
        XCTAssertEqual(personDto.type, "Person", "Property 'type' is not valid.")
        XCTAssertEqual(personDto.inbox, "http://localhost:8000/actors/tronddedal/inbox", "Property 'inbox' is not valid.")
        XCTAssertEqual(personDto.outbox, "http://localhost:8000/actors/tronddedal/outbox", "Property 'outbox' is not valid.")
        XCTAssertEqual(personDto.following, "http://localhost:8000/actors/tronddedal/following", "Property 'inbox' is not valid.")
        XCTAssertEqual(personDto.followers, "http://localhost:8000/actors/tronddedal/followers", "Property 'outbox' is not valid.")
        XCTAssertEqual(personDto.preferredUsername, "tronddedal", "Property 'preferredUsername' is not valid.")
    }
    
    func testActorProfileShouldNotBeReturnedForNotExistingActor() throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/actors/unknown@host.com",
                                                                       version: .none,
                                                                       method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}

