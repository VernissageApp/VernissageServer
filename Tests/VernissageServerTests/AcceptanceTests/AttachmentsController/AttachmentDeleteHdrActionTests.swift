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
    
    @Suite("Attachments (DELETE /attachments/:id/hdr)", .serialized, .tags(.attachments))
    struct AttachmentsDeleteHdrActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("HDR file version should be deleted from attachment")
        func hdrFileVersionShouldBeDeletedFromAttachment() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "vaclavborix")
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
            
            _ = try await application.sendRequest(
                as: .user(userName: "vaclavborix", password: "p@ssword"),
                to: "/attachments/" + (attachment.stringId() ?? "") + "/hdr",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "vaclavborix", password: "p@ssword"),
                to: "/attachments/" + (attachment.stringId() ?? "") + "/hdr",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let attachmentFromDatabase = try await application.getAttachment(userId: user.requireID())

            #expect(attachmentFromDatabase.$originalFile.value != nil, "Attachment orginal file should be set up in database.")
            #expect(attachmentFromDatabase.$smallFile.value != nil, "Attachment small file should be set up in database.")
            #expect(attachmentFromDatabase.$originalHdrFile.id == nil, "Attachment orginal HDR file should be deleted from database.")
        }
        
        @Test("HDR file version should not be deleted from attachment when not authorized user tries to delete")
        func hdrFileVersionShouldNotBeDeletedFromAttachmentWhenNotAuthorizedUserTriesToDelete() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "monikaborix")
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
            
            _ = try await application.sendRequest(
                as: .user(userName: "monikaborix", password: "p@ssword"),
                to: "/attachments/" + (attachment.stringId() ?? "") + "/hdr",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Act.
            let response = try await application.sendRequest(
                to: "/attachments/" + (attachment.stringId() ?? "") + "/hdr",
                method: .DELETE
            )
            
            // Assert.
            let attachmentFromDatabase = try await application.getAttachment(userId: user.requireID())

            defer {
                let orginalHdrFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachmentFromDatabase.originalHdrFile?.fileName ?? "")")
                try? FileManager.default.removeItem(at: orginalHdrFileUrl)
            }
            
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
