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
    
    @Suite("Attachments (POST /attachments)", .serialized, .tags(.attachments))
    struct AttachmentsUploadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Attachment should be saved when image is provided")
        func attachmentShouldBeSavedWhenImageIsProvided() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "vaclavexal")
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "vaclavexal", password: "p@ssword"),
                to: "/attachments",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let attachment = try await application.getAttachment(userId: user.requireID())
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
            
            defer {
                try? FileManager.default.removeItem(at: orginalFileUrl)
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            #expect(attachment.$originalFile.value != nil, "Attachment orginal file should be set up in database.")
            #expect(attachment.$smallFile.value != nil, "Attachment small file should be set up in database.")
            
            let orginalFile = try? Data(contentsOf: orginalFileUrl)
            #expect(orginalFile != nil, "Orginal attachment file sholud be saved into the disk.")
            
            let smallFile = try? Data(contentsOf: orginalFileUrl)
            #expect(smallFile != nil, "Small attachment file sholud be saved into the disk.")
        }
        
        @Test("Attachment should not be uploaded when not authorized user tries to upload")
        func attachmentShouldNotBeUploadedWhenNotAuthorizedUserTriesToUpload() async throws {
            
            // Arrange.
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/attachments",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Attachment should not be uploaded when file is not provided")
        func attachmentShouldNotBeUploadedWhenFileIsNotProvided() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rafaelexal")
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "rafaelexal", password: "p@ssword"),
                to: "/attachments",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "missingImage", "Error code should be equal 'missingImage'.")
        }
        
        @Test("Attachment should not be saved when user email is not verified")
        func attachmentShouldBeSavedWhenUserEmailIsNotVerified() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "robikexal", emailWasConfirmed: false)
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robikexal", password: "p@ssword"),
                to: "/attachments",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "emailNotVerified", "Error code should be equal 'emailNotVerified'.")
        }
    }
}
