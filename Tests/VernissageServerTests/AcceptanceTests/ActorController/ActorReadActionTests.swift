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

@Suite("GET /", .serialized, .tags(.actor))
struct ActorReadActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Unfollow should success when all correct data has been applied")
    func testApplicationActorProfileShouldBeReturned() async throws {
            
        // Act.
        let applicationDto = try application.getResponse(
            to: "/actor",
            version: .none,
            decodeTo: PersonDto.self
        )
        
        // Assert.
        #expect(applicationDto.id == "http://localhost:8080/actor", "Property 'id' is not valid.")
        #expect(applicationDto.type == "Application", "Property 'type' is not valid.")
        #expect(applicationDto.inbox == "http://localhost:8080/actor/inbox", "Property 'inbox' is not valid.")
        #expect(applicationDto.outbox == "http://localhost:8080/actor/outbox", "Property 'outbox' is not valid.")
        #expect(applicationDto.preferredUsername == "localhost", "Property 'preferredUsername' is not valid.")
    }
}

