//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing

@Suite("String URL tests")
struct StringUrlTests {
    
    @Test
    func `Simple file extension should be recognized`() async throws {
        
        // Arrange.
        let fileName = "file.JPG"
        
        // Act.
        let pathExtension = fileName.pathExtension
        
        // Assert.
        #expect(pathExtension == "jpg", "JPG extension should be returned")
    }
    
    @Test
    func `Complex file extension should be recognized`() async throws {
        
        // Arrange.
        let fileName = "file://path/jakies/file-123.png"
        
        // Act.
        let pathExtension = fileName.pathExtension
        
        // Assert.
        #expect(pathExtension == "png", "png extension should be returned")
    }
    
    @Test
    func `JPG file extension should be recognized as image/jpeg mime type`() async throws {
        
        // Arrange.
        let fileName = "file.JPG"
        
        // Act.
        let mimeType = fileName.mimeType
        
        // Assert.
        #expect(mimeType == "image/jpeg", "JPG extension should be returned")
    }
    
    @Test
    func `jpg file extension should be recognized as image/jpeg mime type`() async throws {
        
        // Arrange.
        let fileName = "file.jpg"
        
        // Act.
        let mimeType = fileName.mimeType
        
        // Assert.
        #expect(mimeType == "image/jpeg", "jpg extension should be returned")
    }
    
    @Test
    func `JPEG file extension should be recognized as image/jpeg mime type`() async throws {
        
        // Arrange.
        let fileName = "file.JPEG"
        
        // Act.
        let mimeType = fileName.mimeType
        
        // Assert.
        #expect(mimeType == "image/jpeg", "JPEG extension should be returned")
    }
    
    @Test
    func `jpeg file extension should be recognized as image/jpeg mime type`() async throws {
        
        // Arrange.
        let fileName = "file.jpeg"
        
        // Act.
        let mimeType = fileName.mimeType
        
        // Assert.
        #expect(mimeType == "image/jpeg", "jpeg extension should be returned")
    }
    
    @Test
    func `PNG file extension should be recognized as image/png mime type`() async throws {
        
        // Arrange.
        let fileName = "file.PNG"
        
        // Act.
        let mimeType = fileName.mimeType
        
        // Assert.
        #expect(mimeType == "image/png", "PNG extension should be returned")
    }
    
    @Test
    func `png file extension should be recognized as image/png mime type`() async throws {
        
        // Arrange.
        let fileName = "file.png"
        
        // Act.
        let mimeType = fileName.mimeType
        
        // Assert.
        #expect(mimeType == "image/png", "jpeg extension should be returned")
    }
    
    @Test
    func `Not recognized file extension should be recognized as nil`() async throws {
        
        // Arrange.
        let fileName = "file.ASDASD"
        
        // Act.
        let pathExtension = fileName.pathExtension
        
        // Assert.
        #expect(pathExtension == nil, "nil extension should be returned")
    }
}

