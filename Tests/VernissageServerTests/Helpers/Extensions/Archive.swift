//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Application {
    func createArchive(userId: Int64) async throws -> Archive {
        let id = await ApplicationManager.shared.generateId()
        let archive = Archive(id: id, userId: userId)
        _ = try await archive.save(on: self.db)
        return archive
    }
    
    func getAllArchives(userId: Int64) async throws -> [Archive] {
        return try await Archive.query(on: self.db)
            .with(\.$user)
            .filter(\.$user.$id == userId)
            .all()
    }
    
    func set(archive: Archive, status: ArchiveStatus) async throws {
        archive.status = status
        try await archive.save(on: self.db)
    }
    
    func deleteFile(archives: [Archive]) {
        for archive in archives {
            if let fileName = archive.fileName {
                let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
            }
        }
    }
}
