//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubFollowingActionTests: XCTestCase {
    
    func testFollowingInformationShouldBeReturnedForExistingActor() throws {
        
        // Arrange.
        let userA = try User.create(userName: "monikaduch")
        let userB = try User.create(userName: "karolduch")
        let userC = try User.create(userName: "weronikaduch")

        _ = try Follow.create(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userC.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/monikaduch/following",
            version: .none,
            decodeTo: OrderedCollectionDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8000/actors/monikaduch/following", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.first, "http://localhost:8000/actors/monikaduch/following?page=1", "Property 'first' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollection", "Property 'type' is not valid.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 2, "Property 'totalItems' is not valid.")
    }
    
    func testFirstPropertyShouldNotBeSetForActorsWithoutFollowing() throws {
        
        // Arrange.
        _ = try User.create(userName: "monikaryba")
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/monikaryba/following",
            version: .none,
            decodeTo: OrderedCollectionDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8000/actors/monikaryba/following", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertNil(orderedCollectionDto.first, "Property 'first' should not be set.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollection", "Property 'type' is not valid.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 0, "Property 'totalItems' is not valid.")
    }
    
    func testFollowingInformationShouldNotBeReturnedForNotExistingActor() throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/actors/unknown/following", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testFollowingDataShouldBeReturnedForExistingActor() throws {
        // Arrange.
        let userA = try User.create(userName: "monikatram")
        let userB = try User.create(userName: "karoltram")
        let userC = try User.create(userName: "weronikatram")

        _ = try Follow.create(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userC.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/monikatram/following?page=1",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8000/actors/monikatram/following?page=1", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.partOf, "http://localhost:8000/actors/monikatram/following", "Property 'partOf' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollectionPage", "Property 'type' is not valid.")
        XCTAssertNil(orderedCollectionDto.next, "Property 'next' should not be set.")
        XCTAssertNil(orderedCollectionDto.prev, "Property 'prev' should not be set.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 2, "Property 'totalItems' is not valid.")
        XCTAssertTrue(orderedCollectionDto.orderedItems.contains("http://localhost:8000/actors/karoltram"), "Following 'karoltram' should be visible on list.")
        XCTAssertTrue(orderedCollectionDto.orderedItems.contains("http://localhost:8000/actors/weronikatram"), "Following 'weronikatram' should be visible on list.")
    }
    
    func testNextUrlShouldBeReturnedForLongList() throws {
        // Arrange.
        let userA = try User.create(userName: "adamfuks")
        let userB = try User.create(userName: "karolfuks")
        let userC = try User.create(userName: "monikafuks")
        let userD = try User.create(userName: "robertfuks")
        let userE = try User.create(userName: "franekfuks")
        let userF = try User.create(userName: "marcinfuks")
        let userG = try User.create(userName: "piotrfuks")
        let userH = try User.create(userName: "justynafuks")
        let userI = try User.create(userName: "pawelfuks")
        let userJ = try User.create(userName: "erykfuks")
        let userK = try User.create(userName: "waldekfuks")
        let userL = try User.create(userName: "marianfuks")

        _ = try Follow.create(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userC.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userD.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userE.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userF.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userG.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userH.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userI.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userJ.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userK.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userL.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/adamfuks/following?page=1",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8000/actors/adamfuks/following?page=1", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.partOf, "http://localhost:8000/actors/adamfuks/following", "Property 'partOf' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollectionPage", "Property 'type' is not valid.")
        XCTAssertEqual(orderedCollectionDto.next, "http://localhost:8000/actors/adamfuks/following?page=2", "Property 'next' is not valid.")
        XCTAssertNil(orderedCollectionDto.prev, "Property 'prev' should not be set.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 11, "Property 'totalItems' is not valid.")
        XCTAssertEqual(orderedCollectionDto.orderedItems.count, 10, "List contains wrong number of items.")
    }
    
    func testPrevUrlShouldBeReturnedForLongList() throws {
        // Arrange.
        let userA = try User.create(userName: "adamrak")
        let userB = try User.create(userName: "karolrak")
        let userC = try User.create(userName: "monikarak")
        let userD = try User.create(userName: "robertrak")
        let userE = try User.create(userName: "franekrak")
        let userF = try User.create(userName: "marcinrak")
        let userG = try User.create(userName: "piotrrak")
        let userH = try User.create(userName: "justynarak")
        let userI = try User.create(userName: "pawelrak")
        let userJ = try User.create(userName: "erykrak")
        let userK = try User.create(userName: "waldekrak")
        let userL = try User.create(userName: "marianrak")

        _ = try Follow.create(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userC.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userD.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userE.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userF.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userG.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userH.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userI.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userJ.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userK.requireID())
        _ = try Follow.create(sourceId: userA.requireID(), targetId: userL.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/adamrak/following?page=2",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8000/actors/adamrak/following?page=2", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.partOf, "http://localhost:8000/actors/adamrak/following", "Property 'partOf' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollectionPage", "Property 'type' is not valid.")
        XCTAssertNil(orderedCollectionDto.next, "Property 'next' should not be set.")
        XCTAssertEqual(orderedCollectionDto.prev, "http://localhost:8000/actors/adamrak/following?page=1", "Property 'prev' is not valid.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 11, "Property 'totalItems' is not valid.")
        XCTAssertEqual(orderedCollectionDto.orderedItems.count, 1, "List contains wrong number of items.")
    }
}

