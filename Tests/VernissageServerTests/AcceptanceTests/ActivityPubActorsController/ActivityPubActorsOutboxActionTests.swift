//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Fluent
import Testing
import Vapor

extension ControllersTests {

    @Suite("ActivityPubActor (GET /actors/:username/outbox)", .serialized, .tags(.actors))
    struct ActivityPubActorsOutboxActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Outbox should expose only public local activities of requested actor`() async throws {
            // Arrange.
            let actor = try await application.createUser(userName: "apoutboxactor")
            let otherActor = try await application.createUser(userName: "apoutboxother")
            let publicStatus = try await application.createStatus(user: actor, note: "Public")
            let quietPublicStatus = try await application.createStatus(user: actor, note: "Quiet public", visibility: .quietPublic)
            _ = try await application.createStatus(user: actor, note: "Followers", visibility: .followers)
            _ = try await application.createStatus(user: actor, note: "Mentioned", visibility: .mentioned)
            _ = try await application.createStatus(user: actor, note: "Remote", isLocal: false)
            _ = try await application.createStatus(user: otherActor, note: "Other actor")

            // Act.
            let collection = try await application.getResponse(
                to: "/actors/apoutboxactor/outbox",
                version: .none,
                decodeTo: OrderedCollectionDto.self
            )
            let page = try await application.getResponse(
                to: "/actors/apoutboxactor/outbox?page=true",
                version: .none,
                decodeTo: OrderedCollectionPageDto.self
            )

            // Assert.
            #expect(collection.id == "http://localhost:8080/actors/apoutboxactor/outbox")
            #expect(collection.type == "OrderedCollection")
            #expect(collection.totalItems == 2)
            #expect(collection.first == "http://localhost:8080/actors/apoutboxactor/outbox?page=true")
            #expect(collection.attributedTo == actor.activityPubProfile)
            #expect(collection.orderedItems == nil)

            #expect(page.id == "http://localhost:8080/actors/apoutboxactor/outbox?page=true")
            #expect(page.partOf == collection.id)
            #expect(page.totalItems == 2)
            #expect(page.next == nil)
            #expect(page.prev == nil)

            let items = page.orderedItems.objects()
            #expect(items.map(\.id) == ["\(quietPublicStatus.activityPubId)/activity", "\(publicStatus.activityPubId)/activity"])

            let firstActivity = try #require(items.first?.object as? ActivityDto)
            #expect(firstActivity.type == .create)
            #expect(firstActivity.actor.actorIds() == [actor.activityPubProfile])

            let noteObject = try #require(firstActivity.object.objects().first)
            let note = try #require(noteObject.object as? NoteDto)
            #expect(note.id == quietPublicStatus.activityPubId)
            #expect(note.content?.contains("Quiet public") == true)
        }

        @Test
        func `Outbox should use max id cursor for stable pagination`() async throws {
            // Arrange.
            let actor = try await application.createUser(userName: "apoutboxpaging")
            var statuses: [Status] = []
            for index in 1...11 {
                statuses.append(try await application.createStatus(user: actor, note: "Status \(index)"))
            }

            let expectedCursor = try statuses[1].requireID()

            // Act.
            let firstPage = try await application.getResponse(
                to: "/actors/apoutboxpaging/outbox?page=true",
                version: .none,
                decodeTo: OrderedCollectionPageDto.self
            )
            let secondPage = try await application.getResponse(
                to: "/actors/apoutboxpaging/outbox?page=true&max_id=\(expectedCursor)",
                version: .none,
                decodeTo: OrderedCollectionPageDto.self
            )

            // Assert.
            #expect(firstPage.totalItems == 11)
            #expect(firstPage.orderedItems.objects().count == 10)
            #expect(firstPage.next == "http://localhost:8080/actors/apoutboxpaging/outbox?page=true&max_id=\(expectedCursor)")
            #expect(secondPage.id == "http://localhost:8080/actors/apoutboxpaging/outbox?page=true&max_id=\(expectedCursor)")
            #expect(secondPage.orderedItems.objects().map(\.id) == ["\(statuses[0].activityPubId)/activity"])
            #expect(secondPage.next == nil)
        }

        @Test
        func `Reblog should be exposed as Announce activity`() async throws {
            // Arrange.
            let author = try await application.createUser(userName: "apoutboxauthor")
            let actor = try await application.createUser(userName: "apoutboxbooster")
            let originalStatus = try await application.createStatus(user: author, note: "Original")
            let reblogStatus = try await application.createStatus(user: actor, note: nil, reblogId: originalStatus.requireID())

            // Act.
            let page = try await application.getResponse(
                to: "/actors/apoutboxbooster/outbox?page=true",
                version: .none,
                decodeTo: OrderedCollectionPageDto.self
            )

            // Assert.
            let item = try #require(page.orderedItems.objects().first)
            #expect(item.id == "\(reblogStatus.activityPubId)/activity")

            let activity = try #require(item.object as? AnnouceDto)
            #expect(activity.type == "Announce")
            #expect(activity.actor?.actorIds() == [actor.activityPubProfile])
            #expect(activity.object?.objects().first?.id == originalStatus.activityPubId)
            #expect(activity.cc?.actorIds().contains(author.activityPubProfile) == true)
            #expect(activity.cc?.actorIds().contains("\(actor.activityPubProfile)/followers") == true)
        }

        @Test
        func `Outbox should reject client to server submissions`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "apoutboxpost")

            // Act.
            let response = try await application.sendRequest(
                to: "/actors/apoutboxpost/outbox",
                version: .none,
                method: .POST
            )

            // Assert.
            #expect(response.status == .methodNotAllowed)
            #expect(response.headers.first(name: "Allow") == "GET")
        }

        @Test
        func `Outbox should reject malformed cursor`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "apoutboxcursor")

            // Act.
            let response = try await application.sendRequest(
                to: "/actors/apoutboxcursor/outbox?page=true&max_id=invalid",
                version: .none,
                method: .GET
            )

            // Assert.
            #expect(response.status == .badRequest)
        }

        @Test
        func `Outbox should not be returned for unknown or remote actor`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "apoutboxremote", isLocal: false)

            // Act.
            let unknownResponse = try await application.sendRequest(
                to: "/actors/apoutboxunknown/outbox",
                version: .none,
                method: .GET
            )
            let remoteResponse = try await application.sendRequest(
                to: "/actors/apoutboxremote/outbox",
                version: .none,
                method: .GET
            )

            // Assert.
            #expect(unknownResponse.status == .notFound)
            #expect(remoteResponse.status == .notFound)
        }
    }
}
