//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing
import Fluent

extension ControllersTests {

    @Suite("TimelineMarkers (POST /timeline-markers/:timeline)", .serialized, .tags(.timelineMarkers))
    struct TimelineMarkersUpdateActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Timeline marker should be created for authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "markercreateowner")
            let (statuses, attachments) = try await application.createStatuses(
                user: user,
                notePrefix: "Timeline marker create",
                amount: 1
            )
            defer {
                application.clearFiles(attachments: attachments)
            }

            let status = try #require(statuses.first)
            let timelineMarkerDto = TimelineMarkerDto(statusId: try #require(status.stringId()))

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "markercreateowner", password: "p@ssword"),
                to: "/timeline-markers/private",
                method: .POST,
                body: timelineMarkerDto
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")

            let timelineMarker = try await TimelineMarker.query(on: application.db)
                .filter(\.$user.$id == user.requireID())
                .filter(\.$timeline == .private)
                .first()
            #expect(timelineMarker?.$status.id == status.id, "Timeline marker should point to the selected status.")
        }

        @Test
        func `Existing timeline marker should be updated for authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "markerupdateowner")
            let (statuses, attachments) = try await application.createStatuses(
                user: user,
                notePrefix: "Timeline marker update",
                amount: 2
            )
            defer {
                application.clearFiles(attachments: attachments)
            }

            _ = try await application.createTimelineMarker(user: user, status: statuses[0], timeline: .featured)
            let timelineMarkerDto = TimelineMarkerDto(statusId: try #require(statuses[1].stringId()))

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "markerupdateowner", password: "p@ssword"),
                to: "/timeline-markers/featured",
                method: .POST,
                body: timelineMarkerDto
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")

            let timelineMarkers = try await TimelineMarker.query(on: application.db)
                .filter(\.$user.$id == user.requireID())
                .filter(\.$timeline == .featured)
                .all()
            #expect(timelineMarkers.count == 1, "Existing timeline marker should be updated instead of duplicated.")
            #expect(timelineMarkers.first?.$status.id == statuses[1].id, "Timeline marker should point to the updated status.")
        }

        @Test
        func `Timeline marker should not be updated for unauthorized user`() async throws {
            // Arrange.
            let timelineMarkerDto = TimelineMarkerDto(statusId: "123123123")

            // Act.
            let response = try await application.sendRequest(
                to: "/timeline-markers/local",
                method: .POST,
                body: timelineMarkerDto
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }

        @Test
        func `Timeline marker should not be updated for incorrect timeline`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "markerupdateincorrect")
            let timelineMarkerDto = TimelineMarkerDto(statusId: "123123123")

            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "markerupdateincorrect", password: "p@ssword"),
                to: "/timeline-markers/incorrect",
                method: .POST,
                data: timelineMarkerDto
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "incorrectTimeline", "Error code should indicate incorrect timeline.")
        }

        @Test
        func `Timeline marker should not be updated for incorrect status id`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "markerupdatebadstatus")
            let timelineMarkerDto = TimelineMarkerDto(statusId: "incorrect")

            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "markerupdatebadstatus", password: "p@ssword"),
                to: "/timeline-markers/federated",
                method: .POST,
                data: timelineMarkerDto
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "incorrectStatusId", "Error code should indicate incorrect status id.")
        }

        @Test
        func `Timeline marker should not be updated for missing status`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "markerupdatemissing")
            let timelineMarkerDto = TimelineMarkerDto(statusId: "123123123")

            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "markerupdatemissing", password: "p@ssword"),
                to: "/timeline-markers/federated",
                method: .POST,
                data: timelineMarkerDto
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
            #expect(errorResponse.error.code == "statusNotFound", "Error code should indicate missing status.")
        }
    }
}
