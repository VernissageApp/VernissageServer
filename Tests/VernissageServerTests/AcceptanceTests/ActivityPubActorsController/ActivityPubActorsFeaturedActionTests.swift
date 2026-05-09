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
            #expect(orderedCollectionDto.first == nil, "Property 'first' should not be set.")
            #expect(orderedCollectionDto.attributedTo == "http://localhost:8080/actors/apfeaturedactor", "Property 'attributedTo' is not valid.")
            #expect(orderedCollectionDto.orderedItems?.objects().count == 2, "Pinned statuses list should contain two statuses.")
            #expect(orderedCollectionDto.orderedItems?.objects().first?.id == statuses[2].activityPubId, "Newest pinned status should be first.")
            #expect(orderedCollectionDto.orderedItems?.objects().last?.id == statuses[0].activityPubId, "Older pinned status should be last.")
        }

        @Test
        func `Featured first page should be returned for existing actor`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "apfeaturedpage")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Featured AP page", amount: 3)
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
            let orderedCollectionPageDto = try await application.getResponse(
                to: "/actors/apfeaturedpage/featured?page=1",
                version: .none,
                decodeTo: OrderedCollectionPageDto.self
            )

            // Assert.
            #expect(orderedCollectionPageDto.id == "http://localhost:8080/actors/apfeaturedpage/featured?page=1", "Property 'id' is not valid.")
            #expect(orderedCollectionPageDto.type == "OrderedCollectionPage", "Property 'type' is not valid.")
            #expect(orderedCollectionPageDto.partOf == "http://localhost:8080/actors/apfeaturedpage/featured", "Property 'partOf' is not valid.")
            #expect(orderedCollectionPageDto.totalItems == 2, "Pinned statuses count should be valid.")
            #expect(orderedCollectionPageDto.next == nil, "Property 'next' should not be set.")
            #expect(orderedCollectionPageDto.prev == nil, "Property 'prev' should not be set.")
            #expect(orderedCollectionPageDto.orderedItems.objects().count == 2, "Pinned statuses list should contain two statuses.")
            #expect(orderedCollectionPageDto.orderedItems.objects().first?.id == statuses[2].activityPubId, "Newest pinned status should be first.")
            #expect(orderedCollectionPageDto.orderedItems.objects().last?.id == statuses[0].activityPubId, "Older pinned status should be last.")
        }

        @Test
        func `Featured collection should contain paging links for long list`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "apfeaturedpaging")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Featured AP long", amount: 11)
            defer {
                application.clearFiles(attachments: attachments)
            }

            for status in statuses {
                status.pinnedAt = Date()
                try await status.save(on: application.db)
            }

            // Act.
            let firstPage = try await application.getResponse(
                to: "/actors/apfeaturedpaging/featured?page=1",
                version: .none,
                decodeTo: OrderedCollectionPageDto.self
            )
            let secondPage = try await application.getResponse(
                to: "/actors/apfeaturedpaging/featured?page=2",
                version: .none,
                decodeTo: OrderedCollectionPageDto.self
            )

            // Assert.
            #expect(firstPage.totalItems == 11, "Property 'totalItems' is not valid.")
            #expect(firstPage.next == "http://localhost:8080/actors/apfeaturedpaging/featured?page=2", "Property 'next' is not valid.")
            #expect(firstPage.prev == nil, "Property 'prev' should not be set.")
            #expect(firstPage.orderedItems.objects().count == 10, "List contains wrong number of items.")

            #expect(secondPage.totalItems == 11, "Property 'totalItems' is not valid.")
            #expect(secondPage.next == nil, "Property 'next' should not be set.")
            #expect(secondPage.prev == "http://localhost:8080/actors/apfeaturedpaging/featured?page=1", "Property 'prev' is not valid.")
            #expect(secondPage.orderedItems.objects().count == 1, "List contains wrong number of items.")
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
            #expect(orderedCollectionDto.first == nil, "Property 'first' should not be set.")
            #expect(orderedCollectionDto.orderedItems?.objects().isEmpty ?? true, "Ordered items should be empty.")
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
