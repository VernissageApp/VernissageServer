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
    
    @Suite("Attachments (DELETE /attachments/:id)", .serialized, .tags(.attachments))
    struct AttachmentsDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Attachment should be deleted for authorized user")
        func attachmentShouldBeDeletedForAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "martagrzyb")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "martagrzyb", password: "p@ssword"),
                to: "/attachments/\(attachment.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        }
        
        @Test("Attachment should not be deleted when other user tries to delete")
        func attachmentShouldNotBeDeletedWhenOtherUserTriesToDelete() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "annagrzyb")
            let user = try await application.createUser(userName: "wiktoriagrzyb")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            // Act.
            let errorResponse = try await application.sendRequest(
                as: .user(userName: "annagrzyb", password: "p@ssword"),
                to: "/attachments/\(attachment.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Attachment should not be deleted when it is already connected to status")
        func attachmentShouldNotBeDeletedWhenItIsAlreadyConnectedToStatus() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "igorgrzyb")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            _ = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "igorgrzyb", password: "p@ssword"),
                to: "/attachments/\(attachment.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be ok (400).")
        }
    }
}
