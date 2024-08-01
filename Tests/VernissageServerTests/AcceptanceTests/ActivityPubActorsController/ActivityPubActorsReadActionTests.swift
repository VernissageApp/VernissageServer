//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubActorsReadActionTests: CustomTestCase {
    
    func testActorProfileShouldBeReturnedForExistingActor() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "tronddedal")
        _ = try await FlexiField.create(key: "KEY1", value: "VALUE-A", isVerified: true, userId: user.requireID())
        _ = try await FlexiField.create(key: "KEY2", value: "VALUE-B", isVerified: false, userId: user.requireID())
        
        // Act.
        let personDto = try SharedApplication.application().getResponse(
            to: "/actors/tronddedal",
            version: .none,
            decodeTo: PersonDto.self
        )
        
        // Assert.
        XCTAssertEqual(personDto.id, "http://localhost:8080/actors/tronddedal", "Property 'id' is not valid.")
        XCTAssertEqual(personDto.type, "Person", "Property 'type' is not valid.")
        XCTAssertEqual(personDto.inbox, "http://localhost:8080/actors/tronddedal/inbox", "Property 'inbox' is not valid.")
        XCTAssertEqual(personDto.outbox, "http://localhost:8080/actors/tronddedal/outbox", "Property 'outbox' is not valid.")
        XCTAssertEqual(personDto.following, "http://localhost:8080/actors/tronddedal/following", "Property 'inbox' is not valid.")
        XCTAssertEqual(personDto.followers, "http://localhost:8080/actors/tronddedal/followers", "Property 'outbox' is not valid.")
        XCTAssertEqual(personDto.preferredUsername, "tronddedal", "Property 'preferredUsername' is not valid.")
        
        XCTAssertEqual(personDto.attachment?[0].name, "KEY1", "Property 'fields[0].name' is not valid.")
        XCTAssertEqual(personDto.attachment?[1].name, "KEY2", "Property 'fields[1].name' is not valid.")
        
        XCTAssertEqual(personDto.attachment?[0].value, "VALUE-A", "Property 'fields[0].value' is not valid.")
        XCTAssertEqual(personDto.attachment?[1].value, "VALUE-B", "Property 'fields[1].value' is not valid.")
        
        XCTAssertEqual(personDto.attachment?[0].type, "PropertyValue", "Property 'fields[0].type' is not valid.")
        XCTAssertEqual(personDto.attachment?[1].type, "PropertyValue", "Property 'fields[1].type' is not valid.")
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

