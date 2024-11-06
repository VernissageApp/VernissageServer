//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Queues

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

@_documentation(visibility: private)
protocol TemporaryFileServiceType: Sendable {
    func temporaryPath(based fileName: String, on context: ExecutionContext) throws -> URL
    func save(fileName: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws -> URL
    func save(url: String, on context: ExecutionContext) async throws -> URL
    func delete(url: URL, on request: Request) async throws
}

/// A service for managing temporary files in the system.
final class TemporaryFileService: TemporaryFileServiceType {
    func save(fileName: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws -> URL {
        let temporaryPath = try self.temporaryPath(based: fileName, on: context)
                
        if let fileio = context.fileio {
            try await fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString)
        } else {
            try await context.application.fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString, eventLoop: context.eventLoop)
        }
        
        return temporaryPath
    }
    
    func save(url: String, on context: ExecutionContext) async throws -> URL {
        let fileName = url.fileName
        let temporaryPath = try self.temporaryPath(based: fileName, on: context)
        
        // Download file.
        let byteBuffer = try await self.downloadRemoteResources(url: url, on: context.client)
        
        // Save in tmp directory.
        if let fileio = context.fileio {
            try await fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString)
        } else {
            try await context.application.fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString, eventLoop: context.eventLoop)
        }
        
        return temporaryPath
    }
    
    func temporaryPath(based fileName: String, on context: ExecutionContext) throws -> URL {
        let path = context.application.directory.tempDirectory
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
    
    private func downloadRemoteResources(url: String, on client: Client) async throws -> ByteBuffer {
        let uri = URI(string: url)

        // Request to the remote server.
        let response = try await client.get(uri)
        
        // Validate response.
        switch response.status.code {
        case 200..<300:
            guard let responseByteBuffer = response.body else {
                throw StorageError.emptyBody
            }
            
            return responseByteBuffer
        default:
            throw StorageError.notSuccessResponse(response)
        }
    }
}
