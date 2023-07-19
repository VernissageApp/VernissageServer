//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class StatusesDeleteActionTests: CustomTestCase {
    
    func testStatusShouldBeDeletedForAuthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robinworth")
        let attachment1 = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let status = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "robinworth", password: "p@ssword"),
            to: "/statuses/\(status.requireID())",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let statusFromDatabase = try? await Status.get(id: status.requireID())
        XCTAssert(statusFromDatabase == nil, "Status should be deleted.")
    }
    
    func testStatusShouldNotBeDeletedForUnauthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "erikworth")
        let attachment1 = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let status = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/statuses/\(status.requireID())",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testStatusShouldBeDeletedForStatusCreatedByOtherUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "maciasworth")
        let user = try await User.create(userName: "georgeworth")
        let attachment1 = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let status = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "maciasworth", password: "p@ssword"),
            to: "/statuses/\(status.requireID())",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
}
