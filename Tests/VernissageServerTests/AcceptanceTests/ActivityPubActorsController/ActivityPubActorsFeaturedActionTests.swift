//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing

extension ControllersTests {

    @Suite("ActivityPubActor (GET /actors/:username/featured)", .serialized, .tags(.actors))
    struct ActivityPubActorsFeaturedActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Featured collection should be returned for existing actor`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "apfeaturedactor")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Featured AP", amount: 3)
            defer {
                application.clearFiles(attachments: attachments)
            }

            let newestPinnedAt = Date()
            let olderPinnedAt = newestPinnedAt.addingTimeInterval(-60)

            statuses[0].pinnedAt = olderPinnedAt
            statuses[2].pinnedAt = newestPinnedAt
            try await statuses[0].save(on: application.db)
            try await statuses[2].save(on: application.db)

            // Act.
            let orderedCollectionDto = try await application.getResponse(
                to: "/actors/apfeaturedactor/featured",
                version: .none,
                decodeTo: OrderedCollectionDto.self
            )

            // Assert.
            #expect(orderedCollectionDto.id == "http://localhost:8080/actors/apfeaturedactor/featured", "Property 'id' is not valid.")
            #expect(orderedCollectionDto.context == "https://www.w3.org/ns/activitystreams", "Property 'context' is not valid.")
            #expect(orderedCollectionDto.type == "OrderedCollection", "Property 'type' is not valid.")
            #expect(orderedCollectionDto.totalItems == 2, "Pinned statuses count should be valid.")
            #expect(orderedCollectionDto.attributedTo == "http://localhost:8080/actors/apfeaturedactor", "Property 'attributedTo' is not valid.")
            #expect(orderedCollectionDto.orderedItems?.count == 2, "Pinned statuses list should contain two ids.")
            #expect(orderedCollectionDto.orderedItems?.first == statuses[2].activityPubId, "Newest pinned status should be first.")
            #expect(orderedCollectionDto.orderedItems?.last == statuses[0].activityPubId, "Older pinned status should be last.")
        }

        @Test
        func `Featured collection should be empty for actor without pinned statuses`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "apfeaturedempty")

            // Act.
            let orderedCollectionDto = try await application.getResponse(
                to: "/actors/apfeaturedempty/featured",
                version: .none,
                decodeTo: OrderedCollectionDto.self
            )

            // Assert.
            #expect(orderedCollectionDto.id == "http://localhost:8080/actors/apfeaturedempty/featured", "Property 'id' is not valid.")
            #expect(orderedCollectionDto.totalItems == 0, "Property 'totalItems' is not valid.")
            #expect(orderedCollectionDto.orderedItems?.isEmpty ?? true, "Pinned statuses list should be empty.")
        }

        @Test
        func `Featured collection should not be returned for not existing actor`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/actors/unknown/featured", method: .GET)

            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
