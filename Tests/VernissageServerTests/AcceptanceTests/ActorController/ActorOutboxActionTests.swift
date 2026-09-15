//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Testing
import Vapor

extension ControllersTests {

    @Suite("Actor (GET /actor/outbox)", .serialized, .tags(.actor))
    struct ActorOutboxActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Application outbox should be an empty ordered collection`() async throws {
            // Act.
            let collection = try await application.getResponse(
                to: "/actor/outbox",
                version: .none,
                decodeTo: OrderedCollectionDto.self
            )

            // Assert.
            #expect(collection.id == "http://localhost:8080/actor/outbox")
            #expect(collection.type == "OrderedCollection")
            #expect(collection.totalItems == 0)
            #expect(collection.first == nil)
            #expect(collection.attributedTo == "http://localhost:8080/actor")
            #expect(collection.orderedItems?.objects().isEmpty == true)
        }

        @Test
        func `Application outbox should reject client to server submissions`() async throws {
            // Act.
            let response = try await application.sendRequest(
                to: "/actor/outbox",
                version: .none,
                method: .POST
            )

            // Assert.
            #expect(response.status == .methodNotAllowed)
            #expect(response.headers.first(name: "Allow") == "GET")
        }
    }
}
