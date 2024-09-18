//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing

@Suite("GET /:username/followers", .serialized, .tags(.actors))
struct ActivityPubActorsFollowersActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }
    
    @Test("Followers information should be returned for existing actor")
    func followersInformationShouldBeReturnedForExistingActor() async throws {
        
        // Arrange.
        let userA = try await application.createUser(userName: "monikabrzuch")
        let userB = try await application.createUser(userName: "karolbrzuch")
        let userC = try await application.createUser(userName: "weronikabrzuch")

        _ = try await application.createFollow(sourceId: userB.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userC.requireID(), targetId: userA.requireID())
        
        // Act.
        let orderedCollectionDto = try application.getResponse(
            to: "/actors/monikabrzuch/followers",
            version: .none,
            decodeTo: OrderedCollectionDto.self
        )
        
        // Assert.
        #expect(orderedCollectionDto.id == "http://localhost:8080/actors/monikabrzuch/followers", "Property 'id' is not valid.")
        #expect(orderedCollectionDto.context == "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        #expect(orderedCollectionDto.first == "http://localhost:8080/actors/monikabrzuch/followers?page=1", "Property 'first' is not valid.")
        #expect(orderedCollectionDto.type == "OrderedCollection", "Property 'type' is not valid.")
        #expect(orderedCollectionDto.totalItems == 2, "Property 'totalItems' is not valid.")
    }
    
    @Test("First property should not be set for actors without followers")
    func firstPropertyShouldNotBeSetForActorsWithoutFollowers() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "monikatraba")
        
        // Act.
        let orderedCollectionDto = try application.getResponse(
            to: "/actors/monikatraba/followers",
            version: .none,
            decodeTo: OrderedCollectionDto.self
        )
        
        // Assert.
        #expect(orderedCollectionDto.id == "http://localhost:8080/actors/monikatraba/followers", "Property 'id' is not valid.")
        #expect(orderedCollectionDto.context == "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        #expect(orderedCollectionDto.first == nil, "Property 'first' should not be set.")
        #expect(orderedCollectionDto.type == "OrderedCollection", "Property 'type' is not valid.")
        #expect(orderedCollectionDto.totalItems == 0, "Property 'totalItems' is not valid.")
    }
    
    @Test("Followers information should not be returned for not existing actor")
    func followersInformationShouldNotBeReturnedForNotExistingActor() throws {

        // Act.
        let response = try application.sendRequest(to: "/actors/unknown/followers", method: .GET)

        // Assert.
        #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    @Test("Followers data should be returned for existing actor")
    func followersDataShouldBeReturnedForExistingActor() async throws {
        // Arrange.
        let userA = try await application.createUser(userName: "monikacent")
        let userB = try await application.createUser(userName: "karolcent")
        let userC = try await application.createUser(userName: "weronikacent")

        _ = try await application.createFollow(sourceId: userB.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userC.requireID(), targetId: userA.requireID())
        
        // Act.
        let orderedCollectionDto = try application.getResponse(
            to: "/actors/monikacent/followers?page=1",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        #expect(orderedCollectionDto.id == "http://localhost:8080/actors/monikacent/followers?page=1", "Property 'id' is not valid.")
        #expect(orderedCollectionDto.context == "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        #expect(orderedCollectionDto.partOf == "http://localhost:8080/actors/monikacent/followers", "Property 'partOf' is not valid.")
        #expect(orderedCollectionDto.type == "OrderedCollectionPage", "Property 'type' is not valid.")
        #expect(orderedCollectionDto.next == nil, "Property 'next' should not be set.")
        #expect(orderedCollectionDto.prev == nil, "Property 'prev' should not be set.")
        #expect(orderedCollectionDto.totalItems == 2, "Property 'totalItems' is not valid.")
        #expect(orderedCollectionDto.orderedItems.contains("http://localhost:8080/actors/karolcent"), "Followers 'karoltram' should be visible on list.")
        #expect(orderedCollectionDto.orderedItems.contains("http://localhost:8080/actors/weronikacent"), "Followers 'weronikatram' should be visible on list.")
    }
    
    @Test("Next url should be returned for long list")
    func nextUrlShouldBeReturnedForLongList() async throws {
        // Arrange.
        let userA = try await application.createUser(userName: "adamwara")
        let userB = try await application.createUser(userName: "karolwara")
        let userC = try await application.createUser(userName: "monikawara")
        let userD = try await application.createUser(userName: "robertwara")
        let userE = try await application.createUser(userName: "franekwara")
        let userF = try await application.createUser(userName: "marcinwara")
        let userG = try await application.createUser(userName: "piotrwara")
        let userH = try await application.createUser(userName: "justynawara")
        let userI = try await application.createUser(userName: "pawelwara")
        let userJ = try await application.createUser(userName: "erykwara")
        let userK = try await application.createUser(userName: "waldekwara")
        let userL = try await application.createUser(userName: "marianwara")

        _ = try await application.createFollow(sourceId: userB.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userC.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userD.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userE.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userF.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userG.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userH.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userI.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userJ.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userK.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userL.requireID(), targetId: userA.requireID())
        
        // Act.
        let orderedCollectionDto = try application.getResponse(
            to: "/actors/adamwara/followers?page=1",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        #expect(orderedCollectionDto.id == "http://localhost:8080/actors/adamwara/followers?page=1", "Property 'id' is not valid.")
        #expect(orderedCollectionDto.context == "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        #expect(orderedCollectionDto.partOf == "http://localhost:8080/actors/adamwara/followers", "Property 'partOf' is not valid.")
        #expect(orderedCollectionDto.type == "OrderedCollectionPage", "Property 'type' is not valid.")
        #expect(orderedCollectionDto.next == "http://localhost:8080/actors/adamwara/followers?page=2", "Property 'next' is not valid.")
        #expect(orderedCollectionDto.prev == nil, "Property 'prev' should not be set.")
        #expect(orderedCollectionDto.totalItems == 11, "Property 'totalItems' is not valid.")
        #expect(orderedCollectionDto.orderedItems.count == 10, "List contains wrong number of items.")
    }
    
    @Test("Prev url should be returned for long list")
    func testPrevUrlShouldBeReturnedForLongList() async throws {
        // Arrange.
        let userA = try await application.createUser(userName: "adambuda")
        let userB = try await application.createUser(userName: "karolbuda")
        let userC = try await application.createUser(userName: "monikabuda")
        let userD = try await application.createUser(userName: "robertbuda")
        let userE = try await application.createUser(userName: "franekbuda")
        let userF = try await application.createUser(userName: "marcinbuda")
        let userG = try await application.createUser(userName: "piotrbuda")
        let userH = try await application.createUser(userName: "justynabuda")
        let userI = try await application.createUser(userName: "pawelbuda")
        let userJ = try await application.createUser(userName: "erykbuda")
        let userK = try await application.createUser(userName: "waldekbuda")
        let userL = try await application.createUser(userName: "marianbuda")

        _ = try await application.createFollow(sourceId: userB.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userC.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userD.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userE.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userF.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userG.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userH.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userI.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userJ.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userK.requireID(), targetId: userA.requireID())
        _ = try await application.createFollow(sourceId: userL.requireID(), targetId: userA.requireID())
        
        // Act.
        let orderedCollectionDto = try application.getResponse(
            to: "/actors/adambuda/followers?page=2",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        #expect(orderedCollectionDto.id == "http://localhost:8080/actors/adambuda/followers?page=2", "Property 'id' is not valid.")
        #expect(orderedCollectionDto.context == "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        #expect(orderedCollectionDto.partOf == "http://localhost:8080/actors/adambuda/followers", "Property 'partOf' is not valid.")
        #expect(orderedCollectionDto.type == "OrderedCollectionPage", "Property 'type' is not valid.")
        #expect(orderedCollectionDto.next == nil, "Property 'next' should not be set.")
        #expect(orderedCollectionDto.prev == "http://localhost:8080/actors/adambuda/followers?page=1", "Property 'prev' is not valid.")
        #expect(orderedCollectionDto.totalItems == 11, "Property 'totalItems' is not valid.")
        #expect(orderedCollectionDto.orderedItems.count == 1, "List contains wrong number of items.")
    }
}

