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
    /// Returns a unique temporary file path based on the specified file name.
    /// - Parameters:
    ///   - fileName: Name of the file to base the path on.
    ///   - context: Execution context.
    /// - Returns: Temporary file URL.
    /// - Throws: Errors if URL cannot be created.
    func temporaryPath(based fileName: String, on context: ExecutionContext) throws -> URL
    
    /// Creates a new temporary folder.
    /// - Parameters:
    ///   - folder: Name of the folder to create.
    ///   - context: Execution context.
    /// - Returns: Path to the created folder.
    /// - Throws: Errors if folder cannot be created.
    func create(folder: String, on context: ExecutionContext) async throws -> String
    
    /// Removes the specified temporary folder.
    /// - Parameters:
    ///   - folder: Name of the folder to remove.
    ///   - context: Execution context.
    /// - Throws: Errors if folder cannot be removed.
    func remove(folder: String, on context: ExecutionContext) async throws
    
    /// Saves a file to a temporary path from a ByteBuffer and returns the file URL.
    /// - Parameters:
    ///   - fileName: Name of the file to save.
    ///   - byteBuffer: Buffer containing file data.
    ///   - context: Execution context.
    /// - Returns: Temporary file URL after saving.
    /// - Throws: Errors if file cannot be saved.
    func save(fileName: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws -> URL
    
    /// Saves a file to a temporary path from a ByteBuffer.
    /// - Parameters:
    ///   - path: Path where file should be saved.
    ///   - byteBuffer: Buffer containing file data.
    ///   - context: Execution context.
    /// - Throws: Errors if file cannot be saved.
    func save(path: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws
    
    /// Downloads and saves a remote file to a temporary folder, returns file URL.
    /// - Parameters:
    ///   - url: URL to download from.
    ///   - toFolder: Optional folder to save file in.
    ///   - context: Execution context.
    /// - Returns: Temporary file URL.
    /// - Throws: Errors if download or save fails.
    func save(url: String, toFolder: String?, on context: ExecutionContext) async throws -> URL
    
    /// Deletes a temporary file by URL.
    /// - Parameters:
    ///   - url: URL of the file to delete.
    ///   - context: Execution context.
    /// - Throws: Errors if file cannot be deleted.
    func delete(url: URL, on context: ExecutionContext) async throws
    
    /// Deletes all temporary files matching the suffix.
    /// - Parameters:
    ///   - suffix: Suffix of files to delete.
    ///   - context: Execution context.
    /// - Throws: Errors if files cannot be deleted.
    func delete(suffix: String, on context: ExecutionContext) async throws
    
    /// Moves a temporary file from one path to another.
    /// - Parameters:
    ///   - atPath: Source file path.
    ///   - toPath: Destination file path.
    ///   - context: Execution context.
    /// - Throws: Errors if file cannot be moved.
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
            try await context.application.fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString)
        }
    }
    
    func save(fileName: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws -> URL {
        let temporaryPath = try self.temporaryPath(based: fileName, on: context)
                
        if let fileio = context.fileio {
            try await fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString)
        } else {
            try await context.application.fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString)
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
            try await context.application.fileio.writeFile(byteBuffer, at: temporaryPath.absoluteString)
        }
        
        return temporaryPath
    }
    
    func moveFile(atPath: String, toPath: String, on context: ExecutionContext) async throws {
        let temporaryPath = try self.temporaryPath(suffix: toPath, on: context)
        try FileManager.default.moveItem(atPath: atPath, toPath: temporaryPath.absoluteString)
    }
    
    func temporaryPath(based fileName: String, on context: ExecutionContext) throws -> URL {
        let path = context.application.directory.tempDirectory
            + String.createRandomString(length: 13)
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
