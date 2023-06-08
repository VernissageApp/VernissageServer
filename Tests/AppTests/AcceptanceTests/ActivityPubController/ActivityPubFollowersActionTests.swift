//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubFollowersActionTests: CustomTestCase {
    
    func testFollowersInformationShouldBeReturnedForExistingActor() async throws {
        
        // Arrange.
        let userA = try await User.create(userName: "monikabrzuch")
        let userB = try await User.create(userName: "karolbrzuch")
        let userC = try await User.create(userName: "weronikabrzuch")

        _ = try await Follow.create(sourceId: userB.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userC.requireID(), targetId: userA.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/monikabrzuch/followers",
            version: .none,
            decodeTo: OrderedCollectionDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8000/actors/monikabrzuch/followers", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.first, "http://localhost:8000/actors/monikabrzuch/followers?page=1", "Property 'first' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollection", "Property 'type' is not valid.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 2, "Property 'totalItems' is not valid.")
    }
    
    func testFirstPropertyShouldNotBeSetForActorsWithoutFollowers() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "monikatraba")
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/monikatraba/followers",
            version: .none,
            decodeTo: OrderedCollectionDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8000/actors/monikatraba/followers", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertNil(orderedCollectionDto.first, "Property 'first' should not be set.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollection", "Property 'type' is not valid.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 0, "Property 'totalItems' is not valid.")
    }
    
    func testFollowersInformationShouldNotBeReturnedForNotExistingActor() throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/actors/unknown/followers", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testFollowersDataShouldBeReturnedForExistingActor() async throws {
        // Arrange.
        let userA = try await User.create(userName: "monikacent")
        let userB = try await User.create(userName: "karolcent")
        let userC = try await User.create(userName: "weronikacent")

        _ = try await Follow.create(sourceId: userB.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userC.requireID(), targetId: userA.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/monikacent/followers?page=1",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8000/actors/monikacent/followers?page=1", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.partOf, "http://localhost:8000/actors/monikacent/followers", "Property 'partOf' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollectionPage", "Property 'type' is not valid.")
        XCTAssertNil(orderedCollectionDto.next, "Property 'next' should not be set.")
        XCTAssertNil(orderedCollectionDto.prev, "Property 'prev' should not be set.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 2, "Property 'totalItems' is not valid.")
        XCTAssertTrue(orderedCollectionDto.orderedItems.contains("http://localhost:8000/actors/karolcent"), "Followers 'karoltram' should be visible on list.")
        XCTAssertTrue(orderedCollectionDto.orderedItems.contains("http://localhost:8000/actors/weronikacent"), "Followers 'weronikatram' should be visible on list.")
    }
    
    func testNextUrlShouldBeReturnedForLongList() async throws {
        // Arrange.
        let userA = try await User.create(userName: "adamwara")
        let userB = try await User.create(userName: "karolwara")
        let userC = try await User.create(userName: "monikawara")
        let userD = try await User.create(userName: "robertwara")
        let userE = try await User.create(userName: "franekwara")
        let userF = try await User.create(userName: "marcinwara")
        let userG = try await User.create(userName: "piotrwara")
        let userH = try await User.create(userName: "justynawara")
        let userI = try await User.create(userName: "pawelwara")
        let userJ = try await User.create(userName: "erykwara")
        let userK = try await User.create(userName: "waldekwara")
        let userL = try await User.create(userName: "marianwara")

        _ = try await Follow.create(sourceId: userB.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userC.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userD.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userE.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userF.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userG.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userH.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userI.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userJ.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userK.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userL.requireID(), targetId: userA.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/adamwara/followers?page=1",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8000/actors/adamwara/followers?page=1", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.partOf, "http://localhost:8000/actors/adamwara/followers", "Property 'partOf' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollectionPage", "Property 'type' is not valid.")
        XCTAssertEqual(orderedCollectionDto.next, "http://localhost:8000/actors/adamwara/followers?page=2", "Property 'next' is not valid.")
        XCTAssertNil(orderedCollectionDto.prev, "Property 'prev' should not be set.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 11, "Property 'totalItems' is not valid.")
        XCTAssertEqual(orderedCollectionDto.orderedItems.count, 10, "List contains wrong number of items.")
    }
    
    func testPrevUrlShouldBeReturnedForLongList() async throws {
        // Arrange.
        let userA = try await User.create(userName: "adambuda")
        let userB = try await User.create(userName: "karolbuda")
        let userC = try await User.create(userName: "monikabuda")
        let userD = try await User.create(userName: "robertbuda")
        let userE = try await User.create(userName: "franekbuda")
        let userF = try await User.create(userName: "marcinbuda")
        let userG = try await User.create(userName: "piotrbuda")
        let userH = try await User.create(userName: "justynabuda")
        let userI = try await User.create(userName: "pawelbuda")
        let userJ = try await User.create(userName: "erykbuda")
        let userK = try await User.create(userName: "waldekbuda")
        let userL = try await User.create(userName: "marianbuda")

        _ = try await Follow.create(sourceId: userB.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userC.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userD.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userE.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userF.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userG.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userH.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userI.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userJ.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userK.requireID(), targetId: userA.requireID())
        _ = try await Follow.create(sourceId: userL.requireID(), targetId: userA.requireID())
        
        // Act.
        let orderedCollectionDto = try SharedApplication.application().getResponse(
            to: "/actors/adambuda/followers?page=2",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        XCTAssertEqual(orderedCollectionDto.id, "http://localhost:8000/actors/adambuda/followers?page=2", "Property 'id' is not valid.")
        XCTAssertEqual(orderedCollectionDto.context, "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        XCTAssertEqual(orderedCollectionDto.partOf, "http://localhost:8000/actors/adambuda/followers", "Property 'partOf' is not valid.")
        XCTAssertEqual(orderedCollectionDto.type, "OrderedCollectionPage", "Property 'type' is not valid.")
        XCTAssertNil(orderedCollectionDto.next, "Property 'next' should not be set.")
        XCTAssertEqual(orderedCollectionDto.prev, "http://localhost:8000/actors/adambuda/followers?page=1", "Property 'prev' is not valid.")
        XCTAssertEqual(orderedCollectionDto.totalItems, 11, "Property 'totalItems' is not valid.")
        XCTAssertEqual(orderedCollectionDto.orderedItems.count, 1, "List contains wrong number of items.")
    }
}

