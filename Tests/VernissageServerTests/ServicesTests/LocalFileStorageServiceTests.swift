//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing
import Queues

@Suite("LocalFiltStorageService")
struct LocalFileStorageServiceTests {

    var application: Application!
    
    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }
    
    @Test("Storage should prepare correct file name URL only with file name")
    func storageShouldPrepareCorrectFileNameUrlOnlyWithFileName() async throws {
        // Arrange.
        let storageService = application.services.storageService
        
        // Act.
        let fileName = storageService.generateFileName(url: "file.png")
        
        // Arrange.
        #expect(fileName.pathExtension == "png", "File path extension should be .png.")
        #expect(fileName.count == 36, "File name should have correct length.")
    }
    
    @Test("Storage should prepare correct file name URL with file name and path")
    func storageShouldPrepareCorrectFileNameUrlWithFileNameAndPath() async throws {
        // Arrange.
        let storageService = application.services.storageService
        
        // Act.
        let fileName = storageService.generateFileName(url: "articles/1234567890/file.png")
        
        // Arrange.
        #expect(fileName.pathExtension == "png", "File path extension should be .png.")
        #expect(fileName.starts(with: "articles/1234567890/") == true, "File name should start with correct path.")
        #expect(fileName.count == 56, "File name should have correct length.")
    }
}
