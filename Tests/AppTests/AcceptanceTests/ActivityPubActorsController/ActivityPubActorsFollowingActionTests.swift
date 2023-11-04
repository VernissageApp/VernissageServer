//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubActorsFollowingActionTests: CustomTestCase {
    
    func testFollowingInformationShouldBeReturnedForExistingActor() async throws {
        
        // Arrange.
        let userA = try await User.create(userName: "monikaduch")
        let userB = try await User.create(userName: "karolduch")
        let userC = try await User.create(userName: "weronikaduch")

        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userC.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/monikaduch/following",
            version: .none,
            decodeTo: OrderedCollectionDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8080/actors/monikaduch/following", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.first, "http://localhost:8080/actors/monikaduch/following?page=1", "Property 'first' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollection", "Property 'type' is not valid.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 2, "Property 'totalItems' is not valid.")
    }
    
    func testFirstPropertyShouldNotBeSetForActorsWithoutFollowing() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "monikaryba")
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/monikaryba/following",
            version: .none,
            decodeTo: OrderedCollectionDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8080/actors/monikaryba/following", "Property 'id' is not valid.")
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
    
    func testFollowingDataShouldBeReturnedForExistingActor() async throws {
        // Arrange.
        let userA = try await User.create(userName: "monikatram")
        let userB = try await User.create(userName: "karoltram")
        let userC = try await User.create(userName: "weronikatram")

        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userC.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/monikatram/following?page=1",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8080/actors/monikatram/following?page=1", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.partOf, "http://localhost:8080/actors/monikatram/following", "Property 'partOf' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollectionPage", "Property 'type' is not valid.")
        XCTAssertNil(orderedCollectionDto.next, "Property 'next' should not be set.")
        XCTAssertNil(orderedCollectionDto.prev, "Property 'prev' should not be set.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 2, "Property 'totalItems' is not valid.")
        XCTAssertTrue(orderedCollectionDto.orderedItems.contains("http://localhost:8080/actors/karoltram"), "Following 'karoltram' should be visible on list.")
        XCTAssertTrue(orderedCollectionDto.orderedItems.contains("http://localhost:8080/actors/weronikatram"), "Following 'weronikatram' should be visible on list.")
    }
    
    func testNextUrlShouldBeReturnedForLongList() async throws {
        // Arrange.
        let userA = try await User.create(userName: "adamfuks")
        let userB = try await User.create(userName: "karolfuks")
        let userC = try await User.create(userName: "monikafuks")
        let userD = try await User.create(userName: "robertfuks")
        let userE = try await User.create(userName: "franekfuks")
        let userF = try await User.create(userName: "marcinfuks")
        let userG = try await User.create(userName: "piotrfuks")
        let userH = try await User.create(userName: "justynafuks")
        let userI = try await User.create(userName: "pawelfuks")
        let userJ = try await User.create(userName: "erykfuks")
        let userK = try await User.create(userName: "waldekfuks")
        let userL = try await User.create(userName: "marianfuks")

        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userC.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userD.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userE.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userF.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userG.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userH.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userI.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userJ.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userK.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userL.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/adamfuks/following?page=1",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8080/actors/adamfuks/following?page=1", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.partOf, "http://localhost:8080/actors/adamfuks/following", "Property 'partOf' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollectionPage", "Property 'type' is not valid.")
        XCTAssertEqual(orderedCollectionDto.next, "http://localhost:8080/actors/adamfuks/following?page=2", "Property 'next' is not valid.")
        XCTAssertNil(orderedCollectionDto.prev, "Property 'prev' should not be set.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 11, "Property 'totalItems' is not valid.")
        XCTAssertEqual(orderedCollectionDto.orderedItems.count, 10, "List contains wrong number of items.")
    }
    
    func testPrevUrlShouldBeReturnedForLongList() async throws {
        // Arrange.
        let userA = try await User.create(userName: "adamrak")
        let userB = try await User.create(userName: "karolrak")
        let userC = try await User.create(userName: "monikarak")
        let userD = try await User.create(userName: "robertrak")
        let userE = try await User.create(userName: "franekrak")
        let userF = try await User.create(userName: "marcinrak")
        let userG = try await User.create(userName: "piotrrak")
        let userH = try await User.create(userName: "justynarak")
        let userI = try await User.create(userName: "pawelrak")
        let userJ = try await User.create(userName: "erykrak")
        let userK = try await User.create(userName: "waldekrak")
        let userL = try await User.create(userName: "marianrak")

        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userC.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userD.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userE.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userF.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userG.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userH.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userI.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userJ.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userK.requireID())
        _ = try await Follow.create(sourceId: userA.requireID(), targetId: userL.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/adamrak/following?page=2",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8080/actors/adamrak/following?page=2", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.partOf, "http://localhost:8080/actors/adamrak/following", "Property 'partOf' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollectionPage", "Property 'type' is not valid.")
        XCTAssertNil(orderedCollectionDto.next, "Property 'next' should not be set.")
        XCTAssertEqual(orderedCollectionDto.prev, "http://localhost:8080/actors/adamrak/following?page=1", "Property 'prev' is not valid.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 11, "Property 'totalItems' is not valid.")
        XCTAssertEqual(orderedCollectionDto.orderedItems.count, 1, "List contains wrong number of items.")
    }
}

