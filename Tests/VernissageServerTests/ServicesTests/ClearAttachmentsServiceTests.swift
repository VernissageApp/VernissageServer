//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Testing
import Vapor

@Suite("ClearAttachmentsService", .serialized)
struct ClearAttachmentsServiceTests {
    let application: Application

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test(arguments: [0, 1, 2], [false, true])
    func `Cleanup should remove all related Exif records`(exifCount: Int, isHistory: Bool) async throws {
        let user = try await application.createUser(userName: "clearexif\(exifCount)\(isHistory)")
        let attachment = try await application.createAttachment(user: user)
        let attachmentId = try attachment.requireID()
        let originalFileId = attachment.$originalFile.id
        let smallFileId = attachment.$smallFile.id
        defer { application.clearFiles(attachments: [attachment]) }

        try await Exif.query(on: application.db)
            .filter(\.$attachment.$id == attachmentId)
            .delete()

        let oldDate = Date().addingTimeInterval(-48 * 60 * 60)
        var historyId: Int64?
        if isHistory {
            let history = AttachmentHistory(
                id: application.services.snowflakeService.generate(),
                statusHistoryId: 0,
                from: attachment
            )
            history.$statusHistory.id = nil
            try await history.create(on: application.db)
            history.createdAt = oldDate
            try await history.save(on: application.db)
            historyId = try history.requireID()
        } else {
            attachment.createdAt = oldDate
            try await attachment.save(on: application.db)
        }

        for _ in 0..<exifCount {
            let exif = try #require(Exif(id: application.services.snowflakeService.generate(), make: "Canon"))
            if let historyId {
                let exifHistory = ExifHistory(
                    id: application.services.snowflakeService.generate(),
                    attachmentHistoryId: historyId,
                    from: exif
                )
                try await exifHistory.create(on: application.db)
            } else {
                exif.$attachment.id = attachmentId
                try await exif.create(on: application.db)
            }
        }

        let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext
        try await application.services.clearAttachmentsService.clear(on: context)

        if let historyId {
            #expect(try await AttachmentHistory.find(historyId, on: application.db) == nil)
            #expect(try await ExifHistory.query(on: application.db)
                .filter(\.$attachmentHistory.$id == historyId).count() == 0)
            // The recent attachment still uses these files.
            #expect(try await Attachment.find(attachmentId, on: application.db) != nil)
            #expect(try await FileInfo.find(originalFileId, on: application.db) != nil)
            #expect(try await FileInfo.find(smallFileId, on: application.db) != nil)
        } else {
            #expect(try await Attachment.find(attachmentId, on: application.db) == nil)
            #expect(try await Exif.query(on: application.db)
                .filter(\.$attachment.$id == attachmentId).count() == 0)
            #expect(try await FileInfo.find(originalFileId, on: application.db) == nil)
            #expect(try await FileInfo.find(smallFileId, on: application.db) == nil)
        }
    }
}
