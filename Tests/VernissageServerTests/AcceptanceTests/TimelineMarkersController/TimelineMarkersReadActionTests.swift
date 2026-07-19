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

    @Suite("TimelineMarkers (GET /timeline-markers/:timeline)", .serialized, .tags(.timelineMarkers))
    struct TimelineMarkersReadActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Timeline marker should be returned for authorized user and timeline`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "markerreadowner")
            let otherUser = try await application.createUser(userName: "markerreadother")
            let (statuses, attachments) = try await application.createStatuses(
                user: user,
                notePrefix: "Timeline marker read",
                amount: 2
            )
            defer {
                application.clearFiles(attachments: attachments)
            }

            _ = try await application.createTimelineMarker(user: user, status: statuses[0], timeline: .local)
            _ = try await application.createTimelineMarker(user: user, status: statuses[1], timeline: .federated)
            _ = try await application.createTimelineMarker(user: otherUser, status: statuses[1], timeline: .local)

            // Act.
            let timelineMarkerDto = try await application.getResponse(
                as: .user(userName: "markerreadowner", password: "p@ssword"),
                to: "/timeline-markers/local",
                method: .GET,
                decodeTo: TimelineMarkerDto.self
            )

            // Assert.
            #expect(timelineMarkerDto.statusId == statuses[0].stringId(), "Correct timeline marker should be returned.")
        }

        @Test
        func `Timeline marker should not be returned for unauthorized user`() async throws {
            // Act.
            let response = try await application.sendRequest(
                to: "/timeline-markers/local",
                method: .GET
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }

        @Test
        func `Timeline marker should return not found when marker does not exist`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "markerreadmissing")

            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "markerreadmissing", password: "p@ssword"),
                to: "/timeline-markers/featured",
                method: .GET
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
            #expect(errorResponse.error.code == "timelineMarkerNotFound", "Error code should indicate missing timeline marker.")
        }

        @Test
        func `Timeline marker should not be returned for incorrect timeline`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "markerreadincorrect")

            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "markerreadincorrect", password: "p@ssword"),
                to: "/timeline-markers/incorrect",
                method: .GET
            )

            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "incorrectTimeline", "Error code should indicate incorrect timeline.")
        }
    }
}
