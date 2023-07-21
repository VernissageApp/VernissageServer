//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct TemporaryFileServiceKey: StorageKey {
        typealias Value = TemporaryFileServiceType
    }

    var temporaryFileService: TemporaryFileServiceType {
        get {
            self.application.storage[TemporaryFileServiceKey.self] ?? TemporaryFileService()
        }
        nonmutating set {
            self.application.storage[TemporaryFileServiceKey.self] = newValue
        }
    }
}

protocol TemporaryFileServiceType {
    func temporaryPath(on request: Request, based fileName: String) throws -> URL
    func save(fileName: String, byteBuffer: ByteBuffer, on request: Request) async throws -> URL
    func delete(url: URL, on request: Request) async throws
}

final class TemporaryFileService: TemporaryFileServiceType {
    func save(fileName: String, byteBuffer: ByteBuffer, on request: Request) async throws -> URL {
        let temporaryPath = try self.temporaryPath(on: request, based: fileName)
        try await request.fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString)
        return temporaryPath
    }
    
    func temporaryPath(on request: Request, based fileName: String) throws -> URL {
        let path = request.application.directory.tempDirectory
            + String.createRandomString(length: 12)
            + "-"
        + fileName.replacingOccurrences(of: " ", with: "+")
        
        guard let url = URL(string: path) else {
            throw TemporaryFileError.temporaryUrlFailed
        }
        
        return url
    }
    
    func delete(url: URL, on request: Request) async throws {
        try await request.application.fileio.remove(path: url.absoluteString, eventLoop: request.eventLoop).get()
    }
}
