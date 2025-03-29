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
    
    @Suite("Attachments (POST /attachments/:id/hdr)", .serialized, .tags(.attachments))
    struct AttachmentsUploadHdrActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("HDR file version should be added to attachment")
        func hdrFileVersionShouldBeAddedToAttachment() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "vaclavromdi")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/002.avif"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "002.avif", data: imageFile, mimeType: "image/avif")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "vaclavromdi", password: "p@ssword"),
                to: "/attachments/" + (attachment.stringId() ?? "") + "/hdr",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let attachmentFromDatabase = try await application.getAttachment(userId: user.requireID())
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachmentFromDatabase.originalFile.fileName)")
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachmentFromDatabase.smallFile.fileName)")
            let orginalHdrFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachmentFromDatabase.originalHdrFile?.fileName ?? "")")
            
            defer {
                try? FileManager.default.removeItem(at: orginalFileUrl)
                try? FileManager.default.removeItem(at: smalFileUrl)
                try? FileManager.default.removeItem(at: orginalHdrFileUrl)
            }
            
            #expect(attachmentFromDatabase != nil, "Attachment should be set up in database.")
            #expect(attachmentFromDatabase.$originalFile != nil, "Attachment orginal file should be set up in database.")
            #expect(attachmentFromDatabase.$smallFile != nil, "Attachment small file should be set up in database.")
            #expect(attachmentFromDatabase.$originalHdrFile != nil, "Attachment orginal HDR file should be set up in database.")
            
            let orginalFile = try Data(contentsOf: orginalFileUrl)
            #expect(orginalFile != nil, "Orginal attachment file sholud be saved into the disk.")
            
            let smallFile = try Data(contentsOf: orginalFileUrl)
            #expect(smallFile != nil, "Small attachment file sholud be saved into the disk.")
            
            let orginalHdrFile = try Data(contentsOf: orginalHdrFileUrl)
            #expect(orginalHdrFile != nil, "Orginal HDR attachment file sholud be saved into the disk.")
        }
        
        @Test("HDR file version should be added to attachment when not authorized user tries to upload")
        func hdrFileVersionShouldNotBeAddedToAttachmentWhenNotAuthorizedUserTriesToUpload() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "monikaromdi")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/002.avif"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "002.avif", data: imageFile, mimeType: "image/avif")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/attachments/" + (attachment.stringId() ?? "") + "/hdr",
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
            let user = try await application.createUser(userName: "refaelromdi")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }

            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "refaelromdi", password: "p@ssword"),
                to: "/attachments/" + (attachment.stringId() ?? "") + "/hdr",
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
