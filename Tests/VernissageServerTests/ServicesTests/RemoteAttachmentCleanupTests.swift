//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Fluent
import FluentSQLiteDriver
import Foundation
import Testing
import Vapor
import VaporTesting

struct RemoteAttachmentCleanupTests {
    @Test
    func `A rejected HDR image leaves temporary and stored directories empty`() async throws {
        try await withFixture(rejectHDR: true) { app, note, context in
            await #expect(throws: RemoteResourceDownloadError.nonPublicAddress) {
                try await app.services.statusesService.downloadDirectMessageAttachments(note: note, userId: 1, on: context)
            }

            try expectNoFiles(on: app)
        }
    }

    @Test
    func `A database failure rolls back the file records and removes stored files`() async throws {
        try await withFixture { app, note, context in
            // Keep the Attachments table absent so the transaction fails after inserting the file records.
            try await FileInfo.CreateFileInfos().prepare(on: app.db)

            await #expect(throws: (any Error).self) {
                try await app.services.statusesService.downloadDirectMessageAttachments(note: note, userId: 1, on: context)
            }

            #expect(try await FileInfo.query(on: app.db).count() == 0)
            try expectNoFiles(on: app)
        }
    }

    @Test
    func `A successful import saves the HDR file and its database record`() async throws {
        try await withFixture { app, note, context in
            try await FileInfo.CreateFileInfos().prepare(on: app.db)
            try await app.db.schema(Attachment.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required)
                .field("originalFileId", .int64, .required, .references(FileInfo.schema, "id"))
                .field("smallFileId", .int64, .required, .references(FileInfo.schema, "id"))
                .field("originalHdrFileId", .int64, .references(FileInfo.schema, "id"))
                .field("description", .string)
                .field("blurhash", .string)
                .field("locationId", .int64)
                .field("statusId", .int64)
                .field("licenseId", .int64)
                .field("order", .int, .required)
                .field("originalImagePreserved", .bool, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()

            let attachments = try await app.services.statusesService.downloadDirectMessageAttachments(note: note, userId: 1, on: context)
            let attachment = try #require(attachments.first)
            let hdrId = try #require(attachment.$originalHdrFile.id)
            let hdrFile = try await FileInfo.find(hdrId, on: app.db)
            let fileName = try #require(hdrFile?.fileName)
            let contents = try FileManager.default.contentsOfDirectory(atPath: app.directory.publicDirectory + "storage")

            #expect(contents.count == 3)
            #expect(contents.contains(fileName))
            #expect(try FileManager.default.contentsOfDirectory(atPath: app.directory.tempDirectory).isEmpty)
        }
    }

    private func withFixture(
        rejectHDR: Bool = false,
        test: (Application, NoteDto, ExecutionContext) async throws -> Void
    ) async throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Assets/001.png")
        let body = try ByteBuffer(data: Data(contentsOf: fixture))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        try await withApp { app in
            app.directory = .init(workingDirectory: directory.path)
            try FileManager.default.createDirectory(atPath: app.directory.tempDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: app.directory.publicDirectory + "storage", withIntermediateDirectories: true)
            app.databases.use(.sqlite(.memory), as: .sqlite)
            app.services.remoteResourceDownloadService = FixtureAttachmentDownloadService(body: body, rejectHDR: rejectHDR)

            let request = Request(application: app, on: app.eventLoopGroup.next())
            let note = try NoteDto.imageAttachmentNote(originalImagePreserved: true, fileName: "001.png", includeHDR: true)
            try await test(app, note, request.executionContext)
        }
    }

    private func expectNoFiles(on app: Application) throws {
        #expect(try FileManager.default.contentsOfDirectory(atPath: app.directory.tempDirectory).isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: app.directory.publicDirectory + "storage").isEmpty)
    }
}

private struct FixtureAttachmentDownloadService: RemoteResourceDownloadServiceType {
    let body: ByteBuffer
    let rejectHDR: Bool

    func download(url: String, on context: ExecutionContext) async throws -> ByteBuffer {
        if url == "https://example.org/photo-hdr.jpg" {
            let storagePath = context.application.directory.publicDirectory + "storage"
            #expect(try FileManager.default.contentsOfDirectory(atPath: storagePath).isEmpty)

            if rejectHDR {
                throw RemoteResourceDownloadError.nonPublicAddress
            }
        }

        return body
    }
}
