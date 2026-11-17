//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Fluent
import Foundation
import Testing
import Vapor
import VaporTesting

@Suite(.serialized)
struct OriginalImageFederationTests {
    @Test(arguments: ["2048-P3.jpg", "001.png", "003.webp"])
    func downloadedOriginalKeepsAllBytes(fileName: String) async throws {
        try await withFixture(fileName: fileName) { app, user, original in
            // Arrange.
            let note = try NoteDto.imageAttachmentNote(originalImagePreserved: true, fileName: fileName)

            // Act.
            let attachment = try await app.downloadAttachment(from: note, user: user)
            defer { app.clearFiles(attachments: [attachment]) }

            // Assert.
            #expect(try attachment.originalFile.storedData(on: app) == original)
        }
    }

    @Test(arguments: [true, false])
    func downloadedAttachmentRetainsPreservationFlag(value: Bool) async throws {
        try await withFixture(fileName: "2048-P3.jpg") { app, user, original in
            // Arrange.
            let note = try NoteDto.imageAttachmentNote(originalImagePreserved: value, fileName: "2048-P3.jpg")

            // Act.
            let attachment = try await app.downloadAttachment(from: note, user: user)
            defer { app.clearFiles(attachments: [attachment]) }

            // Assert.
            #expect(attachment.originalImagePreserved == value)
        }
    }

    @Test
    func downloadWithFalsePreservationFlagKeepsExistingStorageBehavior() async throws {
        try await withFixture(fileName: "2048-P3.jpg") { app, user, original in
            // Arrange.
            let note = try NoteDto.imageAttachmentNote(originalImagePreserved: false, fileName: "2048-P3.jpg")

            // Act.
            let attachment = try await app.downloadAttachment(from: note, user: user)
            defer { app.clearFiles(attachments: [attachment]) }

            // Assert.
            #expect(try attachment.originalFile.storedData(on: app) == original)
        }
    }

    @Test
    func downloadedOriginalHasSeparateResizedPreview() async throws {
        try await withFixture(fileName: "2048-P3.jpg") { app, user, original in
            // Arrange.
            let note = try NoteDto.imageAttachmentNote(originalImagePreserved: true, fileName: "2048-P3.jpg")

            // Act.
            let attachment = try await app.downloadAttachment(from: note, user: user)
            defer { app.clearFiles(attachments: [attachment]) }

            // Assert.
            #expect(try attachment.smallFile.storedData(on: app) != original)
            #expect(attachment.smallFile.width == 800)
            #expect(attachment.smallFile.fileName.pathExtension == "jpg")
        }
    }

    @Test(arguments: [("2048-P3.jpg", "image/jpeg"), ("001.png", "image/png"), ("003.webp", "image/webp")])
    func downloadedOriginalUsesActualMediaType(fileName: String, mediaType: String) async throws {
        try await withFixture(fileName: fileName) { app, user, original in
            // Arrange.
            let note = try NoteDto.imageAttachmentNote(originalImagePreserved: true, fileName: fileName)

            // Act.
            let attachment = try await app.downloadAttachment(from: note, user: user)
            defer { app.clearFiles(attachments: [attachment]) }

            // Assert.
            let outgoing = MediaAttachmentDto(from: attachment, baseImagesPath: "https://local.example/storage")
            #expect(outgoing.mediaType == mediaType)
        }
    }

    private func withFixture(fileName: String, test: (Application, User, Data) async throws -> Void) async throws {
        try await withApp(configure: { app in
            let sourcePath = #filePath
            let testsRange = try #require(sourcePath.range(of: "/Tests/"))
            app.directory = .init(workingDirectory: String(sourcePath.prefix(upTo: testsRange.lowerBound)))
            try await app.configure()
        }) { app in
            let user = try await app.createUser(userName: "federatedoriginal")
            let fixture = URL(fileURLWithPath: "\(app.directory.workingDirectory)/Tests/VernissageServerTests/Assets/\(fileName)")
            let original = try Data(contentsOf: fixture)
            let buffer = ByteBuffer(data: original)
            app.clients.use { OriginalImageClient(eventLoop: $0.eventLoopGroup.next(), body: buffer) }
            try await test(app, user, original)
        }
    }


}

private struct OriginalImageClient: Client {
    let eventLoop: EventLoop
    let body: ByteBuffer

    func delegating(to eventLoop: EventLoop) -> any Client {
        OriginalImageClient(eventLoop: eventLoop, body: body)
    }

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        eventLoop.makeSucceededFuture(ClientResponse(status: .ok, body: body))
    }
}
