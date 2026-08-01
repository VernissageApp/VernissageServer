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
    @Suite("Timelines (GET /timelines/camera/:name)", .serialized, .tags(.timelines))
    struct TimelinesCameraActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Statuses should be returned by normalized camera name`() async throws {
            let user = try await application.createUser(userName: "timelinecameranames")
            let olderAttachment = try await application.createAttachment(
                user: user,
                make: "Timeline Camera",
                model: "Timeline Camera X1"
            )
            let unrelatedAttachment = try await application.createAttachment(
                user: user,
                make: "Unrelated Camera",
                model: "U1"
            )
            let newerAttachment = try await application.createAttachment(
                user: user,
                make: "TIMELINE CAMERA",
                model: "X1"
            )
            let quietAttachment = try await application.createAttachment(
                user: user,
                make: "timeline camera",
                model: "timeline camera x1"
            )

            defer {
                application.clearFiles(
                    attachments: [olderAttachment, unrelatedAttachment, newerAttachment, quietAttachment]
                )
            }

            _ = try await application.createStatus(
                user: user,
                note: "Older camera timeline status",
                attachmentIds: [olderAttachment.stringId()!]
            )
            _ = try await application.createStatus(
                user: user,
                note: "Unrelated camera timeline status",
                attachmentIds: [unrelatedAttachment.stringId()!]
            )
            _ = try await application.createStatus(
                user: user,
                note: "Newer camera timeline status",
                attachmentIds: [newerAttachment.stringId()!]
            )
            let quietStatus = try await application.createStatus(
                user: user,
                note: "Quiet camera timeline status",
                attachmentIds: [quietAttachment.stringId()!]
            )
            try await application.changeStatusVisibility(
                statusId: quietStatus.requireID(),
                visibility: .quietPublic
            )

            let statuses = try await application.getResponse(
                as: .user(userName: "timelinecameranames", password: "p@ssword"),
                to: "/timelines/camera/timeline%20camera%20x1?limit=20",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )

            #expect(statuses.data.count == 2)
            #expect(statuses.data[0].note == "Newer camera timeline status")
            #expect(statuses.data[1].note == "Older camera timeline status")
        }

        @Test
        func `Camera timeline should support id pagination`() async throws {
            let user = try await application.createUser(userName: "timelinecamerapagination")
            let firstAttachment = try await application.createAttachment(
                user: user,
                make: "Pagination Camera",
                model: "P1"
            )
            let secondAttachment = try await application.createAttachment(
                user: user,
                make: "PAGINATION CAMERA",
                model: "P1"
            )
            let thirdAttachment = try await application.createAttachment(
                user: user,
                make: "pagination camera",
                model: "p1"
            )

            defer {
                application.clearFiles(attachments: [firstAttachment, secondAttachment, thirdAttachment])
            }

            let firstStatus = try await application.createStatus(
                user: user,
                note: "Camera pagination 1",
                attachmentIds: [firstAttachment.stringId()!]
            )
            let secondStatus = try await application.createStatus(
                user: user,
                note: "Camera pagination 2",
                attachmentIds: [secondAttachment.stringId()!]
            )
            let thirdStatus = try await application.createStatus(
                user: user,
                note: "Camera pagination 3",
                attachmentIds: [thirdAttachment.stringId()!]
            )

            let latest = try await application.getResponse(
                as: .user(userName: "timelinecamerapagination", password: "p@ssword"),
                to: "/timelines/camera/pagination%20camera%20p1?limit=1",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            let older = try await application.getResponse(
                as: .user(userName: "timelinecamerapagination", password: "p@ssword"),
                to: "/timelines/camera/pagination%20camera%20p1?limit=1&maxId=\(thirdStatus.requireID())",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            let newer = try await application.getResponse(
                as: .user(userName: "timelinecamerapagination", password: "p@ssword"),
                to: "/timelines/camera/pagination%20camera%20p1?limit=1&minId=\(firstStatus.requireID())",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )

            #expect(latest.data.first?.id == thirdStatus.stringId())
            #expect(older.data.first?.id == secondStatus.stringId())
            #expect(newer.data.first?.id == secondStatus.stringId())
        }

        @Test
        func `Unknown camera name should return not found`() async throws {
            _ = try await application.createUser(userName: "timelinecameramissing")

            let response = try await application.sendRequest(
                as: .user(userName: "timelinecameramissing", password: "p@ssword"),
                to: "/timelines/camera/missing-camera",
                method: .GET
            )

            #expect(response.status == .notFound)
        }

        @Test
        func `Camera timeline should be forbidden for anonymous users when public access is disabled`() async throws {
            try await application.updateSetting(key: .showCamerasForAnonymous, value: .boolean(false))

            let response = try await application.sendRequest(
                to: "/timelines/camera/any-camera",
                method: .GET
            )

            #expect(response.status == .unauthorized)
        }
    }
}
