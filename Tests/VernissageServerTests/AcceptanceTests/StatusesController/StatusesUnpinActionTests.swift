//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {

    @Suite("Statuses (POST /statuses/:id/unpin)", .serialized, .tags(.statuses))
    struct StatusesUnpinActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Status should be unpinned for owner`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "unpinowneruser")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Unpin", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }

            statuses.first?.pinnedAt = Date()
            try await statuses.first?.save(on: application.db)

            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "unpinowneruser", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/unpin",
                method: .POST,
                decodeTo: StatusDto.self
            )

            // Assert.
            #expect(statusDto.id != nil, "Status wasn't returned.")
            #expect(statusDto.pinnedAt == nil, "Status should be unpinned.")

            let statusFromDb = try await Status.query(on: application.db)
                .filter(\.$id == statuses.first!.requireID())
                .first()

            #expect(statusFromDb?.pinnedAt == nil, "Pinned date should be removed from database.")
        }

        @Test
        func `Forbidden should be returned for other user`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "unpinownerforbidden")
            _ = try await application.createUser(userName: "unpinotherforbidden")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unpin Forbidden", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }

            statuses.first?.pinnedAt = Date()
            try await statuses.first?.save(on: application.db)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "unpinotherforbidden", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/unpin",
                method: .POST
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }

        @Test
        func `Not found should be returned if status not exists`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "unpinnotfound")

            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "unpinnotfound", password: "p@ssword"),
                to: "/statuses/123456789/unpin",
                method: .POST
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }

        @Test
        func `Unauthorized should be returned for not authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "unpinunauthorized")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Unpin Unauthorized", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }

            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/unpin",
                method: .POST
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
