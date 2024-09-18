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

        #expect(relationships.first(where: { $0.userId == user2.stringId() })?.following ?? false, "User 1 follows User 2.")
        #expect(relationships.first(where: { $0.userId == user2.stringId() })?.followedBy == false ?? true, "User 2 is not following User 1.")
        
        #expect(relationships.first(where: { $0.userId == user3.stringId() })?.following ?? false, "User 1 follows User 3.")
        #expect(relationships.first(where: { $0.userId == user3.stringId() })?.followedBy == false ?? true, "User 3 is not following User 1.")
        
        #expect(relationships.first(where: { $0.userId == user4.stringId() })?.following == false ?? true, "User 1 is not following yet User 4.")
        #expect(relationships.first(where: { $0.userId == user4.stringId() })?.requested ?? false, "User 1 requested following User 4.")
        #expect(relationships.first(where: { $0.userId == user4.stringId() })?.followedBy ?? false, "User 4 is following User 1.")
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

