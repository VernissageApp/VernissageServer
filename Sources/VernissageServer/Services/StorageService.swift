//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Queues
import SotoS3

extension Application.Services {
    struct StorageServiceKey: StorageKey {
        typealias Value = StorageServiceType
    }

    var storageService: StorageServiceType {
        get {
            self.application.storage[StorageServiceKey.self] ?? self.getStorateSystem()
        }
        nonmutating set {
            self.application.storage[StorageServiceKey.self] = newValue
        }
    }
    
    private func getStorateSystem() -> StorageServiceType {
        if self.application.objectStorage.s3 != nil {
            return S3StorageService()
        } else {
            return LocalFileStorageService()
        }
    }
}

@_documentation(visibility: private)
protocol StorageServiceType {
    func save(fileName: String, byteBuffer: ByteBuffer, on request: Request) async throws -> String?
    func save(fileName: String, url: URL, on request: Request) async throws -> String?
    func save(fileName: String, url: URL, on context: QueueContext) async throws -> String?
    func getBaseStoragePath(on application: Application) -> String
    
    func dowload(url: String, on request: Request) async throws -> String?
    func dowload(url: String, on context: QueueContext) async throws -> String?
    
    func delete(fileName: String, on request: Request) async throws
    func delete(fileName: String, on context: QueueContext) async throws
}

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
        let uri = URI(string: url)
        let fileExtension = uri.path.split(separator: ".").last ?? "jpg"
        let fileName = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "") + "." + fileExtension

        return fileName
    }
}

/// Service responsible for saving file in local file storage.
fileprivate final class LocalFileStorageService: StorageServiceType {
    func dowload(url: String, on request: Request) async throws -> String? {
        let byteBuffer = try await downloadRemoteResources(url: url, on: request.client)
        return try await self.saveFileToLocalFileSystem(byteBuffer: byteBuffer, fileUri: url, on: request)
    }

    func dowload(url: String, on context: QueueContext) async throws -> String? {
        let byteBuffer = try await downloadRemoteResources(url: url, on: context.application.client)
        return try await self.saveFileToLocalFileSystem(byteBuffer: byteBuffer, fileUri: url, on: context)
    }
    
    func save(fileName: String, byteBuffer: ByteBuffer, on request: Request) async throws -> String? {
        return try await self.saveFileToLocalFileSystem(byteBuffer: byteBuffer, fileUri: fileName, on: request)
    }
    
    func save(fileName: String, url: URL, on request: Request) async throws -> String? {
        return try await self.saveFileToLocalFileSystem(url: url, fileUri: fileName, on: request)
    }
    
    func save(fileName: String, url: URL, on context: QueueContext) async throws -> String? {
        return try await self.saveFileToLocalFileSystem(url: url, fileUri: fileName, on: context)
    }
    
    func delete(fileName: String, on request: Request) async throws {
        try await self.deleteFileFromFileSystem(fileName: fileName, on: request)
    }

    func delete(fileName: String, on context: QueueContext) async throws {
        try await self.deleteFileFromFileSystem(fileName: fileName, on: context)
    }
    
    func getBaseStoragePath(on application: Application) -> String {
        let appplicationSettings = application.settings.cached
        return (appplicationSettings?.baseAddress ?? "").finished(with: "/") + "storage"
    }
    
    private func saveFileToLocalFileSystem(byteBuffer: ByteBuffer, fileUri: String, on request: Request) async throws -> String {
        let publicFolderPath = request.application.directory.publicDirectory
        let fileName = self.generateFileName(url: fileUri)
        let path = publicFolderPath.finished(with: "/") + "storage/" + fileName
        
        try await request.fileio.writeFile(byteBuffer, at: path)
        return fileName
    }
    
    private func saveFileToLocalFileSystem(byteBuffer: ByteBuffer, fileUri: String, on context: QueueContext) async throws -> String {
        let publicFolderPath = context.application.directory.publicDirectory
        let fileName = self.generateFileName(url: fileUri)
        let path = publicFolderPath.finished(with: "/") + "storage/" + fileName
        
        try await context.application.fileio.writeFile(byteBuffer, at: path, eventLoop: context.eventLoop)
        return fileName
    }
        
    private func saveFileToLocalFileSystem(url: URL, fileUri: String, on request: Request) async throws -> String {
        let publicFolderPath = request.application.directory.publicDirectory
        let fileName = self.generateFileName(url: fileUri)
        let path = publicFolderPath.finished(with: "/") + "storage/" + fileName
        
        let byteBuffer = try await request.fileio.collectFile(at: url.absoluteString)
        try await request.fileio.writeFile(byteBuffer, at: path)

        return fileName
    }
    
    private func saveFileToLocalFileSystem(url: URL, fileUri: String, on context: QueueContext) async throws -> String {
        let publicFolderPath = context.application.directory.publicDirectory
        let fileName = self.generateFileName(url: fileUri)
        let path = publicFolderPath.finished(with: "/") + "storage/" + fileName
        
        let byteBuffer = try await context.application.fileio.collectFile(at: url.absoluteString,
                                                                          allocator: context.application.allocator,
                                                                          eventLoop: context.eventLoop)
        try await context.application.fileio.writeFile(byteBuffer, at: path, eventLoop: context.eventLoop)

        return fileName
    }

    private func deleteFileFromFileSystem(fileName: String, on request: Request) async throws {
        let publicFolderPath = request.application.directory.publicDirectory
        let path = publicFolderPath.finished(with: "/") + "storage/" + fileName
        
        // Remove file from storage.
        try await request.application.fileio.remove(path: path, eventLoop: request.eventLoop).get()
    }
    
    private func deleteFileFromFileSystem(fileName: String, on context: QueueContext) async throws {
        let publicFolderPath = context.application.directory.publicDirectory
        let path = publicFolderPath.finished(with: "/") + "storage/" + fileName
        
        // Remove file from storage.
        try await context.application.fileio.remove(path: path, eventLoop: context.eventLoop).get()
    }
}

/// Service responsible for saving files in S3 compatible object storage.
fileprivate final class S3StorageService: StorageServiceType {
    func dowload(url: String, on request: Request) async throws -> String? {
        let byteBuffer = try await downloadRemoteResources(url: url, on: request.client)
        return try await self.saveFileToObjectStorage(byteBuffer: byteBuffer, fileUri: url, on: request.application)
    }
    
    func dowload(url: String, on context: QueueContext) async throws -> String? {
        let byteBuffer = try await downloadRemoteResources(url: url, on: context.application.client)
        return try await self.saveFileToObjectStorage(byteBuffer: byteBuffer, fileUri: url, on: context.application)
    }
    
    func save(fileName: String, byteBuffer: ByteBuffer, on request: Request) async throws -> String? {
        return try await self.saveFileToObjectStorage(byteBuffer: byteBuffer, fileUri: fileName, on: request.application)
    }
    
    func save(fileName: String, url: URL, on request: Request) async throws -> String? {
        return try await self.saveFileToObjectStorage(url: url, fileUri: fileName, on: request)
    }
    
    func save(fileName: String, url: URL, on context: QueueContext) async throws -> String? {
        return try await self.saveFileToObjectStorage(url: url, fileUri: fileName, on: context)
    }
    
    func delete(fileName: String, on request: Request) async throws {
        try await self.deleteFileFromObjectStorage(fileName: fileName, on: request)
    }

    func delete(fileName: String, on context: QueueContext) async throws {
        try await self.deleteFileFromObjectStorage(fileName: fileName, on: context)
    }
    
    func getBaseStoragePath(on application: Application) -> String {
        let s3Address = application.settings.cached?.s3Address ?? ""
        let s3Bucket = application.settings.cached?.s3Bucket ?? ""

        return "\(s3Address)/\(s3Bucket)"
    }
        
    private func saveFileToObjectStorage(byteBuffer: ByteBuffer, fileUri: String, on application: Application) async throws -> String {
        guard let s3 = application.objectStorage.s3 else {
            application.logger.error("File cannot be stored. S3 object storage is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        guard let bucket = application.settings.cached?.s3Bucket else {
            application.logger.error("File cannot be stored. S3 object storage bucket is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        let fileName = self.generateFileName(url: fileUri)
        
        let putObjectRequest = S3.PutObjectRequest(
            acl: .publicRead,
            body: .byteBuffer(byteBuffer),
            bucket: bucket,
            key: fileName
        )
        
        _ = try await s3.with(timeout: .seconds(60)).putObject(putObjectRequest)
        return fileName
    }
    
    private func saveFileToObjectStorage(url: URL, fileUri: String, on request: Request) async throws -> String {
        guard let s3 = request.objectStorage.s3 else {
            request.logger.error("File cannot be stored. S3 object storage is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        guard let bucket = request.application.settings.cached?.s3Bucket else {
            request.logger.error("File cannot be stored. S3 object storage bucket is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        let byteBuffer = try await request.fileio.collectFile(at: url.absoluteString)

        let fileName = self.generateFileName(url: fileUri)
        let putObjectRequest = S3.PutObjectRequest(
            acl: .publicRead,
            body: .byteBuffer(byteBuffer),
            bucket: bucket,
            key: fileName
        )
        
        _ = try await s3.with(timeout: .seconds(60)).putObject(putObjectRequest)
        return fileName
    }
    
    private func saveFileToObjectStorage(url: URL, fileUri: String, on context: QueueContext) async throws -> String {
        guard let s3 = context.application.objectStorage.s3 else {
            context.logger.error("File cannot be stored. S3 object storage is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        guard let bucket = context.application.settings.cached?.s3Bucket else {
            context.logger.error("File cannot be stored. S3 object storage bucket is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        let byteBuffer = try await context.application.fileio.collectFile(at: url.absoluteString,
                                                                          allocator: context.application.allocator,
                                                                          eventLoop: context.eventLoop)

        let fileName = self.generateFileName(url: fileUri)
        let putObjectRequest = S3.PutObjectRequest(
            acl: .publicRead,
            body: .byteBuffer(byteBuffer),
            bucket: bucket,
            key: fileName
        )
        
        _ = try await s3.with(timeout: .seconds(60)).putObject(putObjectRequest)
        return fileName
    }
        
    private func deleteFileFromObjectStorage(fileName: String, on request: Request) async throws {
        guard let s3 = request.objectStorage.s3 else {
            request.logger.error("File cannot be stored. S3 object storage is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        guard let bucket = request.application.settings.cached?.s3Bucket else {
            request.logger.error("File cannot be stored. S3 object storage bucket is not configured!")
            throw StorageError.s3StorageNotConfigured
        }

        let deleteObjectRequest = S3.DeleteObjectRequest(bucket: bucket, key: fileName)
        _ = try await s3.deleteObject(deleteObjectRequest)
    }
    
    private func deleteFileFromObjectStorage(fileName: String, on context: QueueContext) async throws {
        guard let s3 = context.application.objectStorage.s3 else {
            context.logger.error("File cannot be stored. S3 object storage is not configured!")
            throw StorageError.s3StorageNotConfigured
        }
        
        guard let bucket = context.application.settings.cached?.s3Bucket else {
            context.logger.error("File cannot be stored. S3 object storage bucket is not configured!")
            throw StorageError.s3StorageNotConfigured
        }

        let deleteObjectRequest = S3.DeleteObjectRequest(bucket: bucket, key: fileName)
        _ = try await s3.deleteObject(deleteObjectRequest)
    }
}
