//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

private enum StorageSystem {
    case localFileSystem
    case s3bjectStorage
}

extension Application.Services {
    struct StorageServiceKey: StorageKey {
        typealias Value = StorageServiceType
    }

    var storageService: StorageServiceType {
        get {
            self.application.storage[StorageServiceKey.self] ?? StorageService()
        }
        nonmutating set {
            self.application.storage[StorageServiceKey.self] = newValue
        }
    }
}

protocol StorageServiceType {
    func dowload(url: String, on request: Request) async throws -> String?
    func getBaseStoragePath(on request: Request) -> String
}

final class StorageService: StorageServiceType {
    func dowload(url: String, on request: Request) async throws -> String? {
        let byteBuffer = try await downloadRemoteResources(url: url, on: request)
        
        switch self.getStorateSystem() {
        case .localFileSystem:
            return try await self.saveFileToLocalFileSystem(byteBuffer: byteBuffer, url: url, on: request)
        case .s3bjectStorage:
            throw StorageError.notSupportedStorage
        }
        
    }
    
    func getBaseStoragePath(on request: Request) -> String {
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)

        switch self.getStorateSystem() {
        case .localFileSystem:
            return (appplicationSettings?.baseAddress ?? "").finished(with: "/") + "storage"
        case .s3bjectStorage:
            return ""
        }
    }
    
    private func downloadRemoteResources(url: String, on request: Request) async throws -> ByteBuffer {
        let uri = URI(string: url)

        // Request to the remote server.
        let response = try await request.client.get(uri)
        
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
    
    private func saveFileToLocalFileSystem(byteBuffer: ByteBuffer, url: String, on request: Request) async throws -> String {
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)

        guard let publicFolderPath = appplicationSettings?.publicFolderPath else {
            throw StorageError.emptyPublicFolderPath
        }
        
        let fileName = self.generateFileName(url: url)
        let path = publicFolderPath.finished(with: "/") + "storage/" + fileName
        
        try await request.fileio.writeFile(byteBuffer, at: path)
        return fileName
    }
    
    private func getStorateSystem() -> StorageSystem {
        return .localFileSystem
    }
    
    private func generateFileName(url: String) -> String {
        let uri = URI(string: url)
        let fileExtension = uri.path.split(separator: ".").last ?? "jpg"
        let fileName = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "") + "." + fileExtension

        return fileName
    }
}
