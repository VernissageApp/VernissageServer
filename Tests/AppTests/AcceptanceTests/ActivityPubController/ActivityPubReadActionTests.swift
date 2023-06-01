@testable import App
import XCTest
import XCTVapor

final class ReadActionTests: XCTestCase {
    
    func testActorProfileShouldBeReturnedForExistingActor() throws {
        
        // Arrange.
        _ = try User.create(userName: "tronddedal")
        
        // Act.
        let actorDto = try SharedApplication.application().getResponse(
            to: "/actors/tronddedal",
            decodeTo: ActorDto.self
        )
        
        // Assert.
        XCTAssertEqual(actorDto.id, "http://localhost:8000/actors/tronddedal", "Property 'id' is not valid.")
        XCTAssertEqual(actorDto.type, "Person", "Property 'type' is not valid.")
        XCTAssertEqual(actorDto.inbox, "http://localhost:8000/actors/tronddedal/inbox", "Property 'inbox' is not valid.")
        XCTAssertEqual(actorDto.outbox, "http://localhost:8000/actors/tronddedal/outbox", "Property 'outbox' is not valid.")
        XCTAssertEqual(actorDto.following, "http://localhost:8000/actors/tronddedal/following", "Property 'inbox' is not valid.")
        XCTAssertEqual(actorDto.followers, "http://localhost:8000/actors/tronddedal/followers", "Property 'outbox' is not valid.")
        XCTAssertEqual(actorDto.preferredUsername, "tronddedal", "Property 'preferredUsername' is not valid.")
    }
    
    func testActorProfileShouldNotBeReturnedForNotExistingActor() throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/actors/unknown@host.com", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}

