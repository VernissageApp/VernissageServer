//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

@Suite("GET /relationships", .serialized, .tags(.relationships))
struct RelationshipsListActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Relatonships list should be returned for authorized user")
    func relatonshipsListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        let user1 = try await application.createUser(userName: "wictorrele")
        let user2 = try await application.createUser(userName: "marianrele")
        let user3 = try await application.createUser(userName: "annarele")
        let user4 = try await application.createUser(userName: "mariarele")
        
        _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user3.requireID(), approved: true)
        _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user4.requireID(), approved: false)
        _ = try await application.createFollow(sourceId: user4.requireID(), targetId: user1.requireID(), approved: true)

        // Act.
        let relationships = try application.getResponse(
            as: .user(userName: "wictorrele", password: "p@ssword"),
            to: "/relationships?id[]=\(user2.requireID())&id[]=\(user3.requireID())&id[]=\(user4.requireID())",
            method: .GET,
            decodeTo: [RelationshipDto].self
        )

        // Assert.
        #expect(relationships.count == 3, "All relationships should be returned.")

        let user2Relationship = relationships.first(where: { $0.userId == user2.stringId() })
        #expect(user2Relationship?.following == true, "User 1 follows User 2.")
        #expect(user2Relationship?.followedBy == false, "User 2 is not following User 1.")
        
        let user3Relationship = relationships.first(where: { $0.userId == user3.stringId() })
        #expect(user3Relationship?.following == true, "User 1 follows User 3.")
        #expect(user3Relationship?.followedBy == false, "User 3 is not following User 1.")
        
        let user4Relationship = relationships.first(where: { $0.userId == user4.stringId() })
        #expect(user4Relationship?.following == false, "User 1 is not following yet User 4.")
        #expect(user4Relationship?.requested == true, "User 1 requested following User 4.")
        #expect(user4Relationship?.followedBy == true, "User 4 is following User 1.")
    }
    
    @Test("Relationships list should not be returned for unauthorized user")
    func relationshipsListShouldNotBeReturnedForUnauthorizedUser() async throws {
        // Arrange.
        let user1 = try await application.createUser(userName: "hermanrele")
        let user2 = try await application.createUser(userName: "robinrele")
        
        _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        
        // Act.
        let response = try application.sendRequest(
            to: "/relationships?id[]=\(user2.requireID())",
            method: .GET
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

