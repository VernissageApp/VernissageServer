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
    func create(folder: String, on context: ExecutionContext) async throws -> String
    func remove(folder: String, on context: ExecutionContext) async throws
    func save(fileName: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws -> URL
    func save(path: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws
    func save(url: String, toFolder: String?, on context: ExecutionContext) async throws -> URL
    func delete(url: URL, on context: ExecutionContext) async throws
    func delete(suffix: String, on context: ExecutionContext) async throws
    func moveFile(atPath: String, toPath: String, on context: ExecutionContext) async throws
}

/// A service for managing temporary files in the system.
final class TemporaryFileService: TemporaryFileServiceType {
    func create(folder: String, on context: ExecutionContext) async throws -> String {
        let path = try self.temporaryPath(suffix: folder, on: context)
        
        if let _ = context.fileio {
            throw TemporaryFileError.notImplemented
        } else {
            try await context.application.fileio.createDirectory(path: path.absoluteString, mode: S_IRWXU)
            return path.absoluteString
        }
    }
    
    func remove(folder: String, on context: ExecutionContext) async throws {
        let path = try self.temporaryPath(suffix: folder, on: context)

        // I cannot find the NIO version of these methods unfortunatelly.
        if FileManager.default.fileExists(atPath: path.absoluteString) {
            try FileManager.default.removeItem(atPath: path.absoluteString)
        }
    }

    func save(path: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws {
        let temporaryPath = try self.temporaryPath(suffix: path, on: context)
        
        if let fileio = context.fileio {
            try await fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString)
        } else {
            try await context.application.fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString, eventLoop: context.eventLoop)
        }
    }
    
    func save(fileName: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws -> URL {
        let temporaryPath = try self.temporaryPath(based: fileName, on: context)
                
        if let fileio = context.fileio {
            try await fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString)
        } else {
            try await context.application.fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString, eventLoop: context.eventLoop)
        }
        
        return temporaryPath
    }
    
    func save(url: String, toFolder: String? = nil, on context: ExecutionContext) async throws -> URL {
        let fileName = url.fileName
        let temporaryPath = if let toFolder {
            try self.temporaryPath(suffix: "\(toFolder)/\(fileName)", on: context)
        } else {
            try self.temporaryPath(based: fileName, on: context)
        }
        
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
    
    func moveFile(atPath: String, toPath: String, on context: ExecutionContext) async throws {
        let temporaryPath = try self.temporaryPath(suffix: toPath, on: context)
        try FileManager.default.moveItem(atPath: atPath, toPath: temporaryPath.absoluteString)
    }
    
    func temporaryPath(based fileName: String, on context: ExecutionContext) throws -> URL {
        let path = context.application.directory.tempDirectory
            + String.createRandomString(length: 12)
            + "."
            + (fileName.pathExtension ?? "jpg")
        
        guard let url = URL(string: path) else {
            throw TemporaryFileError.temporaryUrlFailed
        }
        
        return url
    }
    
    func temporaryPath(suffix path: String, on context: ExecutionContext) throws -> URL {
        let path = context.application.directory.tempDirectory
            + path.replacingOccurrences(of: " ", with: "+")
        
        guard let url = URL(string: path) else {
            throw TemporaryFileError.temporaryUrlFailed
        }
        
        return url
    }
    
    func delete(url: URL, on context: ExecutionContext) async throws {
        try await context.application.fileio.remove(path: url.path(), eventLoop: context.eventLoop).get()
    }

    func delete(suffix: String, on context: ExecutionContext) async throws {
        let path = try self.temporaryPath(suffix: suffix, on: context)
        try await context.application.fileio.remove(path: path.path(), eventLoop: context.eventLoop).get()
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
