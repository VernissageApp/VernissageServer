//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Testing
import Vapor

extension ControllersTests {
    @Suite("Timelines (GET /timelines/film/:name)", .serialized, .tags(.timelines))
    struct TimelinesFilmActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Statuses should be returned by normalized film name`() async throws {
            let user = try await application.createUser(userName: "timelinefilmnames")
            let olderAttachment = try await application.createAttachment(
                user: user,
                film: "Timeline Film 400"
            )
            let unrelatedAttachment = try await application.createAttachment(
                user: user,
                film: "Unrelated Film"
            )
            let newerAttachment = try await application.createAttachment(
                user: user,
                film: "TIMELINE FILM 400"
            )
            let quietAttachment = try await application.createAttachment(
                user: user,
                film: "timeline film 400"
            )

            defer {
                application.clearFiles(
                    attachments: [olderAttachment, unrelatedAttachment, newerAttachment, quietAttachment]
                )
            }

            _ = try await application.createStatus(
                user: user,
                note: "Older film timeline status",
                attachmentIds: [olderAttachment.stringId()!]
            )
            _ = try await application.createStatus(
                user: user,
                note: "Unrelated film timeline status",
                attachmentIds: [unrelatedAttachment.stringId()!]
            )
            _ = try await application.createStatus(
                user: user,
                note: "Newer film timeline status",
                attachmentIds: [newerAttachment.stringId()!]
            )
            let quietStatus = try await application.createStatus(
                user: user,
                note: "Quiet film timeline status",
                attachmentIds: [quietAttachment.stringId()!]
            )
            try await application.changeStatusVisibility(
                statusId: quietStatus.requireID(),
                visibility: .quietPublic
            )

            let statuses = try await application.getResponse(
                as: .user(userName: "timelinefilmnames", password: "p@ssword"),
                to: "/timelines/film/Timeline%20Film%20400?limit=20",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )

            #expect(statuses.data.count == 2)
            #expect(statuses.data[0].note == "Newer film timeline status")
            #expect(statuses.data[1].note == "Older film timeline status")
        }

        @Test
        func `Unknown film name should return not found`() async throws {
            _ = try await application.createUser(userName: "timelinefilmmissing")

            let response = try await application.sendRequest(
                as: .user(userName: "timelinefilmmissing", password: "p@ssword"),
                to: "/timelines/film/missing-film",
                method: .GET
            )

            #expect(response.status == .notFound)
        }

        @Test
        func `Film timeline should be forbidden for anonymous users when public access is disabled`() async throws {
            try await application.updateSetting(key: .showFilmsForAnonymous, value: .boolean(false))

            let response = try await application.sendRequest(
                to: "/timelines/film/any-film",
                method: .GET
            )

            #expect(response.status == .unauthorized)
        }
    }
}
