//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Headers (POST /headers/:id)", .serialized, .tags(.headers))
    struct HeadersPostActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Header should be saved when image is provided")
        func headerShouldBeSavedWhenImageIsProvided() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "triskulka")
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "triskulka", password: "p@ssword"),
                to: "/headers/@triskulka",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userAfterRequest = try await application.getUser(userName: "triskulka")
            #expect(userAfterRequest.headerFileName != nil, "Header should be set up in database.")
            
            let headerFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(userAfterRequest.headerFileName!)")
            let headerFile = try Data(contentsOf: headerFileUrl)
            #expect(headerFile != nil, "Header file sholud be saved into the disk.")
            
            try FileManager.default.removeItem(at: headerFileUrl)
        }
        
        @Test("Header should not be changed when not authorized user tries to update header")
        func headerShouldNotBeChangedWhenNotAuthorizedUserTriesToUpdateHeader() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "romankulka")
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/headers/@romankulka",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Header should not be changed when different user updates header")
        func headerShouldNotBeChangedWhenDifferentUserUpdatesHeader() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "vikikulka")
            _ = try await application.createUser(userName: "erikkulka")
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "erikkulka", password: "p@ssword"),
                to: "/headers/@vikikulka",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Header should not be changed when file is not provided")
        func headerShouldNotBeChangedWhenFileIsNotProvided() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "tedkulka")
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "tedkulka", password: "p@ssword"),
                to: "/headers/@tedkulka",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "missingImage", "Error code should be equal 'missingImage'.")
        }
    }
}
