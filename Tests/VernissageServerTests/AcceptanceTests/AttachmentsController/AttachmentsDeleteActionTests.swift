//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class AttachmentsDeleteActionTests: CustomTestCase {
    func testAttachmentShouldBeDeletedForAuthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "martagrzyb")
        let attachment = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
                
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "martagrzyb", password: "p@ssword"),
            to: "/attachments/\(attachment.stringId() ?? "")",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }
    
    func testAttachmentShouldNotBeDeletedWhenOtherUserTriesToDelete() async throws {

        // Arrange.
        _ = try await User.create(userName: "annagrzyb")
        let user = try await User.create(userName: "wiktoriagrzyb")
        let attachment = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
                
        // Act.
        let errorResponse = try SharedApplication.application().sendRequest(
            as: .user(userName: "annagrzyb", password: "p@ssword"),
            to: "/attachments/\(attachment.stringId() ?? "")",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testAttachmentShouldNotBeDeletedWhenItIsAlreadyConnectedToStatus() async throws {

        // Arrange.
        let user = try await User.create(userName: "igorgrzyb")
        let attachment = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        _ = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
                
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "igorgrzyb", password: "p@ssword"),
            to: "/attachments/\(attachment.stringId() ?? "")",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.badRequest, "Response http status code should be ok (400).")
    }
}
