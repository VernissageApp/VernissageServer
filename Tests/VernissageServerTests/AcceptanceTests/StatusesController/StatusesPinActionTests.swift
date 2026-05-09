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

    @Suite("Statuses (POST /statuses/:id/pin)", .serialized, .tags(.statuses))
    struct StatusesPinActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Status should be pinned for owner`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "pinowneruser")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Pin", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }

            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "pinowneruser", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/pin",
                method: .POST,
                decodeTo: StatusDto.self
            )

            // Assert.
            #expect(statusDto.id != nil, "Status wasn't returned.")
            #expect(statusDto.pinnedAt != nil, "Status should be marked as pinned.")

            let statusFromDb = try await Status.query(on: application.db)
                .filter(\.$id == statuses.first!.requireID())
                .first()

            #expect(statusFromDb?.pinnedAt != nil, "Pinned date should be saved in database.")
        }

        @Test
        func `Forbidden should be returned for other user`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "pinownerforbidden")
            _ = try await application.createUser(userName: "pinotherforbidden")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Pin Forbidden", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "pinotherforbidden", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/pin",
                method: .POST
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }

        @Test
        func `Forbidden should be returned for non public status`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "pinprivateowner")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Pin Private", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }

            let statusId = try statuses.first!.requireID()
            statuses.first!.visibility = .followers
            try await statuses.first!.save(on: application.db)

            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "pinprivateowner", password: "p@ssword"),
                to: "/statuses/\(statusId)/pin",
                method: .POST
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == StatusError.cannotPinNonPublicStatus.rawValue, "Response error code should be cannotPinNonPublicStatus.")

            let statusFromDb = try await Status.query(on: application.db)
                .filter(\.$id == statusId)
                .first()
            #expect(statusFromDb?.pinnedAt == nil, "Pinned date should not be saved for non public status.")
        }

        @Test
        func `Forbidden should be returned for comment status`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "pincommentowner")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Pin Comment", amount: 2)
            defer {
                application.clearFiles(attachments: attachments)
            }

            let mainStatusId = try statuses[0].requireID()
            let commentStatusId = try statuses[1].requireID()

            statuses[1].$replyToStatus.id = mainStatusId
            statuses[1].$mainReplyToStatus.id = mainStatusId
            try await statuses[1].save(on: application.db)

            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "pincommentowner", password: "p@ssword"),
                to: "/statuses/\(commentStatusId)/pin",
                method: .POST
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == StatusError.cannotPinComment.rawValue, "Response error code should be cannotPinComment.")

            let statusFromDb = try await Status.query(on: application.db)
                .filter(\.$id == commentStatusId)
                .first()
            #expect(statusFromDb?.pinnedAt == nil, "Pinned date should not be saved for comment status.")
        }

        @Test
        func `Forbidden should be returned for reblog status`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "pinreblogowner")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Pin Reblog", amount: 2)
            defer {
                application.clearFiles(attachments: attachments)
            }

            let sourceStatusId = try statuses[0].requireID()
            let reblogStatusId = try statuses[1].requireID()

            statuses[1].$reblog.id = sourceStatusId
            try await statuses[1].save(on: application.db)

            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "pinreblogowner", password: "p@ssword"),
                to: "/statuses/\(reblogStatusId)/pin",
                method: .POST
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == StatusError.cannotPinReblog.rawValue, "Response error code should be cannotPinReblog.")

            let statusFromDb = try await Status.query(on: application.db)
                .filter(\.$id == reblogStatusId)
                .first()
            #expect(statusFromDb?.pinnedAt == nil, "Pinned date should not be saved for reblog status.")
        }

        @Test
        func `Not found should be returned if status not exists`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "pinnotfound")

            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "pinnotfound", password: "p@ssword"),
                to: "/statuses/123456789/pin",
                method: .POST
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }

        @Test
        func `Unauthorized should be returned for not authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "pinunauthorized")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Pin Unauthorized", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }

            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/pin",
                method: .POST
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
