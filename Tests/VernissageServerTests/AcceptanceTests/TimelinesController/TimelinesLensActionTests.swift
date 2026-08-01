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
    @Suite("Timelines (GET /timelines/lens/:name)", .serialized, .tags(.timelines))
    struct TimelinesLensActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Statuses should be returned by normalized lens name`() async throws {
            let user = try await application.createUser(userName: "timelinelensnames")
            let olderAttachment = try await application.createAttachment(
                user: user,
                lens: "Timeline Lens 50mm"
            )
            let unrelatedAttachment = try await application.createAttachment(
                user: user,
                lens: "Unrelated Lens"
            )
            let newerAttachment = try await application.createAttachment(
                user: user,
                lens: "TIMELINE LENS 50MM"
            )
            let quietAttachment = try await application.createAttachment(
                user: user,
                lens: "timeline lens 50mm"
            )

            defer {
                application.clearFiles(
                    attachments: [olderAttachment, unrelatedAttachment, newerAttachment, quietAttachment]
                )
            }

            _ = try await application.createStatus(
                user: user,
                note: "Older lens timeline status",
                attachmentIds: [olderAttachment.stringId()!]
            )
            _ = try await application.createStatus(
                user: user,
                note: "Unrelated lens timeline status",
                attachmentIds: [unrelatedAttachment.stringId()!]
            )
            _ = try await application.createStatus(
                user: user,
                note: "Newer lens timeline status",
                attachmentIds: [newerAttachment.stringId()!]
            )
            let quietStatus = try await application.createStatus(
                user: user,
                note: "Quiet lens timeline status",
                attachmentIds: [quietAttachment.stringId()!]
            )
            try await application.changeStatusVisibility(
                statusId: quietStatus.requireID(),
                visibility: .quietPublic
            )

            let statuses = try await application.getResponse(
                as: .user(userName: "timelinelensnames", password: "p@ssword"),
                to: "/timelines/lens/TIMELINE%20LENS%2050MM?limit=20",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )

            #expect(statuses.data.count == 2)
            #expect(statuses.data[0].note == "Newer lens timeline status")
            #expect(statuses.data[1].note == "Older lens timeline status")
        }

        @Test
        func `Unknown lens name should return not found`() async throws {
            _ = try await application.createUser(userName: "timelinelensmissing")

            let response = try await application.sendRequest(
                as: .user(userName: "timelinelensmissing", password: "p@ssword"),
                to: "/timelines/lens/missing-lens",
                method: .GET
            )

            #expect(response.status == .notFound)
        }

        @Test
        func `Lens timeline should be forbidden for anonymous users when public access is disabled`() async throws {
            try await application.updateSetting(key: .showLensesForAnonymous, value: .boolean(false))

            let response = try await application.sendRequest(
                to: "/timelines/lens/any-lens",
                method: .GET
            )

            #expect(response.status == .unauthorized)
        }
    }
}
