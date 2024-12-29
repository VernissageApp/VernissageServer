//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Queues
import SotoCore
import SotoSNS

extension Application.Services {
    struct StorageServiceKey: StorageKey {
        typealias Value = StorageServiceType
    }

    var storageService: StorageServiceType {
        get {
            self.application.storage[StorageServiceKey.self] ?? self.getStorageSystem()
        }
        nonmutating set {
            self.application.storage[StorageServiceKey.self] = newValue
        }
    }
    
    private func getStorageSystem() -> StorageServiceType {
        if self.application.objectStorage.s3 != nil {
            return S3StorageService()
        } else {
            return LocalFileStorageService()
        }
    }
}

@_documentation(visibility: private)
protocol StorageServiceType: Sendable {
    func getBaseStoragePath(on context: ExecutionContext) -> String
    func get(fileName: String, on context: ExecutionContext) async throws -> ByteBuffer
    func save(fileName: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws -> String
    func save(fileName: String, url: URL, on context: ExecutionContext) async throws -> String
    func dowload(url: String, on context: ExecutionContext) async throws -> String
    func delete(fileName: String, on context: ExecutionContext) async throws
}

/// A service for managing resource files in the system.
extension StorageServiceType {
    func downloadRemoteResources(url: String, on client: Client) async throws -> ByteBuffer {
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
    
    func generateFileName(url: String) -> String {
        let fileExtension = url.pathExtension ?? "jpg"
        let fileName = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "") + "." + fileExtension

        return fileName
    }
}

/// Service responsible for saving file in local file storage.
fileprivate final class LocalFileStorageService: StorageServiceType {
    func get(fileName: String, on context: ExecutionContext) async throws -> ByteBuffer {
        return try await self.getFileFromLocalFileSystem(fileName: fileName, on: context)
    }
    
    func dowload(url: String, on context: ExecutionContext) async throws -> String {
        let byteBuffer = try await downloadRemoteResources(url: url, on: context.client)
        return try await self.saveFileToLocalFileSystem(byteBuffer: byteBuffer, fileUri: url, on: context)
    }

    func save(fileName: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws -> String {
        return try await self.saveFileToLocalFileSystem(byteBuffer: byteBuffer, fileUri: fileName, on: context)
    }
    
    func save(fileName: String, url: URL, on context: ExecutionContext) async throws -> String {
        return try await self.saveFileToLocalFileSystem(url: url, fileUri: fileName, on: context)
    }
    
    func delete(fileName: String, on context: ExecutionContext) async throws {
        try await self.deleteFileFromFileSystem(fileName: fileName, on: context)
    }
    
    func getBaseStoragePath(on context: ExecutionContext) -> String {
        let appplicationSettings = context.application.settings.cached
        return (appplicationSettings?.baseAddress ?? "").finished(with: "/") + "storage"
    }

    private func getFileFromLocalFileSystem(fileName: String, on context: ExecutionContext) async throws -> ByteBuffer {
        let publicFolderPath = context.application.directory.publicDirectory
        let path = publicFolderPath.finished(with: "/") + "storage/" + fileName
        
        // First we can try to download via request file IO.
        if let fileConent = try await context.fileio?.collectFile(at: path) {
            return fileConent
        }
        
        // If we are not in the request context then we can try to download via application file IO.
        return try await context.application.fileio.collectFile(at: path, allocator: ByteBufferAllocator(), eventLoop: context.eventLoop)
    }
    
    private func saveFileToLocalFileSystem(byteBuffer: ByteBuffer, fileUri: String, on context: ExecutionContext) async throws -> String {
        let publicFolderPath = context.application.directory.publicDirectory
        let fileName = self.generateFileName(url: fileUri)
        let path = publicFolderPath.finished(with: "/") + "storage/" + fileName
        
        if let fileio = context.fileio {
            try await fileio.writeFile(byteBuffer, at: path)
        } else {
            try await context.application.fileio.writeFile(byteBuffer, at: path, eventLoop: context.eventLoop)
        }

        return fileName
    }
            
    private func saveFileToLocalFileSystem(url: URL, fileUri: String, on context: ExecutionContext) async throws -> String {
        let publicFolderPath = context.application.directory.publicDirectory
        let fileName = self.generateFileName(url: fileUri)
        let path = publicFolderPath.finished(with: "/") + "storage/" + fileName
        
        // Read the file.
        let byteBuffer = if let fileio = context.fileio {
            try await fileio.collectFile(at: url.absoluteString)
        } else {
            try await context.application.fileio.collectFile(at: path, allocator: ByteBufferAllocator(), eventLoop: context.eventLoop)
        }
        
        // Write file.
        if let fileio = context.fileio {
            try await fileio.writeFile(byteBuffer, at: path)
        } else {
            try await context.application.fileio.writeFile(byteBuffer, at: path, eventLoop: context.eventLoop)
        }
        
        return fileName
    }
        
    private func deleteFileFromFileSystem(fileName: String, on context: ExecutionContext) async throws {
        let publicFolderPath = context.application.directory.publicDirectory
        let path = publicFolderPath.finished(with: "/") + "storage/" + fileName
        
        // Remove file from storage.
        try await context.application.fileio.remove(path: path, eventLoop: context.eventLoop).get()
    }
}

/// Service responsible for saving files in S3 compatible object storage.
fileprivate final class S3StorageService: StorageServiceType {
    func get(fileName: String, on context: ExecutionContext) async throws -> ByteBuffer {
        return try await self.getFileFromObjectStorage(fileName: fileName, on: context)
    }
    
    func dowload(url: String, on context: ExecutionContext) async throws -> String {
        let byteBuffer = try await downloadRemoteResources(url: url, on: context.client)
        return try await self.saveFileToObjectStorage(byteBuffer: byteBuffer, fileUri: url, on: context)
    }
        
    func save(fileName: String, byteBuffer: ByteBuffer, on context: ExecutionContext) async throws -> String {
        return try await self.saveFileToObjectStorage(byteBuffer: byteBuffer, fileUri: fileName, on: context)
    }
    
    func save(fileName: String, url: URL, on context: ExecutionContext) async throws -> String {
        return try await self.saveFileToObjectStorage(url: url, fileUri: fileName, on: context)
    }

    func delete(fileName: String, on context: ExecutionContext) async throws {
        try await self.deleteFileFromObjectStorage(fileName: fileName, on: context)
    }
    
    func getBaseStoragePath(on context: ExecutionContext) -> String {
        let s3Address = context.application.settings.cached?.s3Address ?? ""
        let s3Bucket = context.application.settings.cached?.s3Bucket ?? ""

        return "\(s3Address)/\(s3Bucket)"
    }
    
    private func getFileFromObjectStorage(fileName: String, on context: ExecutionContext) async throws -> ByteBuffer {
        guard let s3 = context.application.objectStorage.s3 else {
            context.logger.warning("File cannot be stored. S3 object storage is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        guard let bucket = context.settings.cached?.s3Bucket else {
            context.logger.warning("File cannot be stored. S3 object storage bucket is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
                        
        let getObjectRequest = S3.GetObjectRequest(
            bucket: bucket,
            key: fileName
        )
        
        let result = try await s3.with(timeout: .seconds(10)).getObject(getObjectRequest)
        return try await result.body.collect(upTo: 10_000_000)
    }
        
    private func saveFileToObjectStorage(byteBuffer: ByteBuffer, fileUri: String, on context: ExecutionContext) async throws -> String {
        guard let s3 = context.application.objectStorage.s3 else {
            context.logger.warning("File cannot be stored. S3 object storage is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        guard let bucket = context.settings.cached?.s3Bucket else {
            context.logger.warning("File cannot be stored. S3 object storage bucket is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        let fileName = self.generateFileName(url: fileUri)
        let contentType = fileUri.mimeType
                
        let putObjectRequest = S3.PutObjectRequest(
            acl: .publicRead,
            body: .init(buffer: byteBuffer),
            bucket: bucket,
            cacheControl: MaxAge.year.rawValue,
            contentType: contentType,
            key: fileName
        )
        
        _ = try await s3.with(timeout: .seconds(60)).putObject(putObjectRequest)
        return fileName
    }
        
    private func saveFileToObjectStorage(url: URL, fileUri: String, on context: ExecutionContext) async throws -> String {
        guard let s3 = context.application.objectStorage.s3 else {
            context.logger.warning("File cannot be stored. S3 object storage is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        guard let bucket = context.application.settings.cached?.s3Bucket else {
            context.logger.warning("File cannot be stored. S3 object storage bucket is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
                
        let byteBuffer = if let fileio = context.fileio {
            try await fileio.collectFile(at: url.path())
        } else {
            try await context.application.fileio.collectFile(at: url.path(),
                                                             allocator: context.application.allocator,
                                                             eventLoop: context.eventLoop)
        }

        let fileName = self.generateFileName(url: fileUri)
        let contentType = fileUri.mimeType

        let putObjectRequest = S3.PutObjectRequest(
            acl: .publicRead,
            body: .init(buffer: byteBuffer),
            bucket: bucket,
            cacheControl: MaxAge.year.rawValue,
            contentType: contentType,
            key: fileName
        )
        
        _ = try await s3.with(timeout: .seconds(60)).putObject(putObjectRequest)
        return fileName
    }
            
    private func deleteFileFromObjectStorage(fileName: String, on context: ExecutionContext) async throws {
        guard let s3 = context.application.objectStorage.s3 else {
            context.logger.warning("File cannot be stored. S3 object storage is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        guard let bucket = context.application.settings.cached?.s3Bucket else {
            context.logger.warning("File cannot be stored. S3 object storage bucket is not configured!")
            throw StorageError.s3StorageNotConfigured
        }

        let deleteObjectRequest = S3.DeleteObjectRequest(bucket: bucket, key: fileName)
        _ = try await s3.deleteObject(deleteObjectRequest)
    }
}
