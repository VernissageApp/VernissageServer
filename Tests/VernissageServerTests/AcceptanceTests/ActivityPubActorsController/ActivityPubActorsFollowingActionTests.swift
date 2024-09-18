//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing

@Suite("GET /:username/following", .serialized, .tags(.actors))
struct ActivityPubActorsFollowingActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }
    
    @Test("Following information should be returned for existing actor")
    func followingInformationShouldBeReturnedForExistingActor() async throws {
        
        // Arrange.
        let userA = try await application.createUser(userName: "monikaduch")
        let userB = try await application.createUser(userName: "karolduch")
        let userC = try await application.createUser(userName: "weronikaduch")

        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userC.requireID())
        
        // Act.
        let orderedCollectionDto = try application.getResponse(
            to: "/actors/monikaduch/following",
            version: .none,
            decodeTo: OrderedCollectionDto.self
        )
        
        // Assert.
        #expect(orderedCollectionDto.id == "http://localhost:8080/actors/monikaduch/following", "Property 'id' is not valid.")
        #expect(orderedCollectionDto.context == "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        #expect(orderedCollectionDto.first == "http://localhost:8080/actors/monikaduch/following?page=1", "Property 'first' is not valid.")
        #expect(orderedCollectionDto.type == "OrderedCollection", "Property 'type' is not valid.")
        #expect(orderedCollectionDto.totalItems == 2, "Property 'totalItems' is not valid.")
    }
    
    @Test("First property should not be set for actors without following")
    func firstPropertyShouldNotBeSetForActorsWithoutFollowing() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "monikaryba")
        
        // Act.
        let orderedCollectionDto = try application.getResponse(
            to: "/actors/monikaryba/following",
            version: .none,
            decodeTo: OrderedCollectionDto.self
        )
        
        // Assert.
        #expect(orderedCollectionDto.id == "http://localhost:8080/actors/monikaryba/following", "Property 'id' is not valid.")
        #expect(orderedCollectionDto.context == "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        #expect(orderedCollectionDto.first == nil, "Property 'first' should not be set.")
        #expect(orderedCollectionDto.type == "OrderedCollection", "Property 'type' is not valid.")
        #expect(orderedCollectionDto.totalItems == 0, "Property 'totalItems' is not valid.")
    }
    
    @Test("Following information should not be returned for not existing actor")
    func followingInformationShouldNotBeReturnedForNotExistingActor() throws {

        // Act.
        let response = try application.sendRequest(to: "/actors/unknown/following", method: .GET)

        // Assert.
        #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    @Test("Following data should be returned for existing actor")
    func followingDataShouldBeReturnedForExistingActor() async throws {
        // Arrange.
        let userA = try await application.createUser(userName: "monikatram")
        let userB = try await application.createUser(userName: "karoltram")
        let userC = try await application.createUser(userName: "weronikatram")

        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userC.requireID())
        
        // Act.
        let orderedCollectionDto = try application.getResponse(
            to: "/actors/monikatram/following?page=1",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        #expect(orderedCollectionDto.id == "http://localhost:8080/actors/monikatram/following?page=1", "Property 'id' is not valid.")
        #expect(orderedCollectionDto.context == "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        #expect(orderedCollectionDto.partOf == "http://localhost:8080/actors/monikatram/following", "Property 'partOf' is not valid.")
        #expect(orderedCollectionDto.type == "OrderedCollectionPage", "Property 'type' is not valid.")
        #expect(orderedCollectionDto.next == nil, "Property 'next' should not be set.")
        #expect(orderedCollectionDto.prev == nil, "Property 'prev' should not be set.")
        #expect(orderedCollectionDto.totalItems == 2, "Property 'totalItems' is not valid.")
        #expect(orderedCollectionDto.orderedItems.contains("http://localhost:8080/actors/karoltram"), "Following 'karoltram' should be visible on list.")
        #expect(orderedCollectionDto.orderedItems.contains("http://localhost:8080/actors/weronikatram"), "Following 'weronikatram' should be visible on list.")
    }
    
    @Test("Next url should be returned for long list")
    func nextUrlShouldBeReturnedForLongList() async throws {
        // Arrange.
        let userA = try await application.createUser(userName: "adamfuks")
        let userB = try await application.createUser(userName: "karolfuks")
        let userC = try await application.createUser(userName: "monikafuks")
        let userD = try await application.createUser(userName: "robertfuks")
        let userE = try await application.createUser(userName: "franekfuks")
        let userF = try await application.createUser(userName: "marcinfuks")
        let userG = try await application.createUser(userName: "piotrfuks")
        let userH = try await application.createUser(userName: "justynafuks")
        let userI = try await application.createUser(userName: "pawelfuks")
        let userJ = try await application.createUser(userName: "erykfuks")
        let userK = try await application.createUser(userName: "waldekfuks")
        let userL = try await application.createUser(userName: "marianfuks")

        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userC.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userD.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userE.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userF.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userG.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userH.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userI.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userJ.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userK.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userL.requireID())
        
        // Act.
        let orderedCollectionDto = try application.getResponse(
            to: "/actors/adamfuks/following?page=1",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        #expect(orderedCollectionDto.id == "http://localhost:8080/actors/adamfuks/following?page=1", "Property 'id' is not valid.")
        #expect(orderedCollectionDto.context == "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        #expect(orderedCollectionDto.partOf == "http://localhost:8080/actors/adamfuks/following", "Property 'partOf' is not valid.")
        #expect(orderedCollectionDto.type == "OrderedCollectionPage", "Property 'type' is not valid.")
        #expect(orderedCollectionDto.next == "http://localhost:8080/actors/adamfuks/following?page=2", "Property 'next' is not valid.")
        #expect(orderedCollectionDto.prev == nil, "Property 'prev' should not be set.")
        #expect(orderedCollectionDto.totalItems == 11, "Property 'totalItems' is not valid.")
        #expect(orderedCollectionDto.orderedItems.count == 10, "List contains wrong number of items.")
    }
    
    @Test("Prev url should be returned for long list")
    func prevUrlShouldBeReturnedForLongList() async throws {
        // Arrange.
        let userA = try await application.createUser(userName: "adamrak")
        let userB = try await application.createUser(userName: "karolrak")
        let userC = try await application.createUser(userName: "monikarak")
        let userD = try await application.createUser(userName: "robertrak")
        let userE = try await application.createUser(userName: "franekrak")
        let userF = try await application.createUser(userName: "marcinrak")
        let userG = try await application.createUser(userName: "piotrrak")
        let userH = try await application.createUser(userName: "justynarak")
        let userI = try await application.createUser(userName: "pawelrak")
        let userJ = try await application.createUser(userName: "erykrak")
        let userK = try await application.createUser(userName: "waldekrak")
        let userL = try await application.createUser(userName: "marianrak")

        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userB.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userC.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userD.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userE.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userF.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userG.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userH.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userI.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userJ.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userK.requireID())
        _ = try await application.createFollow(sourceId: userA.requireID(), targetId: userL.requireID())
        
        // Act.
        let orderedCollectionDto = try application.getResponse(
            to: "/actors/adamrak/following?page=2",
            version: .none,
            decodeTo: OrderedCollectionPageDto.self
        )
        
        // Assert.
        #expect(orderedCollectionDto.id == "http://localhost:8080/actors/adamrak/following?page=2", "Property 'id' is not valid.")
        #expect(orderedCollectionDto.context == "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
        #expect(orderedCollectionDto.partOf == "http://localhost:8080/actors/adamrak/following", "Property 'partOf' is not valid.")
        #expect(orderedCollectionDto.type == "OrderedCollectionPage", "Property 'type' is not valid.")
        #expect(orderedCollectionDto.next == nil, "Property 'next' should not be set.")
        #expect(orderedCollectionDto.prev == "http://localhost:8080/actors/adamrak/following?page=1", "Property 'prev' is not valid.")
        #expect(orderedCollectionDto.totalItems == 11, "Property 'totalItems' is not valid.")
        #expect(orderedCollectionDto.orderedItems.count == 1, "List contains wrong number of items.")
    }
}

