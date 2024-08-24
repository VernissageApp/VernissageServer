//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class ActorReadActionTests: CustomTestCase {
    
    func testApplicationActorProfileShouldBeReturned() async throws {
            
        // Act.
        let applicationDto = try SharedApplication.application().getResponse(
            to: "/actor",
            version: .none,
            decodeTo: PersonDto.self
        )
        
        // Assert.
        XCTAssertEqual(applicationDto.id, "http://localhost:8080/actor", "Property 'id' is not valid.")
        XCTAssertEqual(applicationDto.type, "Application", "Property 'type' is not valid.")
        XCTAssertEqual(applicationDto.inbox, "http://localhost:8080/actor/inbox", "Property 'inbox' is not valid.")
        XCTAssertEqual(applicationDto.outbox, "http://localhost:8080/actor/outbox", "Property 'outbox' is not valid.")
        XCTAssertEqual(applicationDto.preferredUsername, "localhost", "Property 'preferredUsername' is not valid.")
    }
}

