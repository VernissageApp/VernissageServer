//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor

/// Supplies a fixture image for a single remote URL; delegates resizing, storage and cleanup to the real services.
struct FixtureTemporaryFileService: TemporaryFileServiceType {
    let base: any TemporaryFileServiceType
    static let imageUrl = "https://remote.example/private-photo.png"

    func temporaryPath(based fileName: String, on context: ExecutionContext) throws -> URL {
        try base.temporaryPath(based: fileName, on: context)
    }

    func create(folder: String, on context: ExecutionContext) async throws -> String {
        try await base.create(folder: folder, on: context)
    }

    func remove(folder: String, on context: ExecutionContext) async throws {
        try await base.remove(folder: folder, on: context)
    }

    func save(fileName: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws -> URL {
        try await base.save(fileName: fileName, byteBuffer: byteBuffer, on: context)
    }

    func save(path: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws {
        try await base.save(path: path, byteBuffer: byteBuffer, on: context)
    }

    func save(url: String, toFolder: String?, on context: ExecutionContext) async throws -> URL {
        if url == Self.imageUrl {
            let image = try Data(contentsOf: URL(fileURLWithPath: context.application.directory.workingDirectory + "Tests/VernissageServerTests/Assets/001.png"))

            return try await base.save(fileName: "private-photo.png", byteBuffer: ByteBuffer(data: image), on: context)
        }

        return try await base.save(url: url, toFolder: toFolder, on: context)
    }

    func delete(url: URL, on context: ExecutionContext) async throws {
        try await base.delete(url: url, on: context)
    }

    func delete(suffix: String, on context: ExecutionContext) async throws {
        try await base.delete(suffix: suffix, on: context)
    }

    func moveFile(atPath: String, toPath: String, on context: ExecutionContext) async throws {
        try await base.moveFile(atPath: atPath, toPath: toPath, on: context)
    }
}
