//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class UsersStatusesActionTests: CustomTestCase {
    func testAllStatusesListShouldBeReturnedForOwner() async throws {
        // Arrange.
        let user = try await User.create(userName: "robinbrin")

        let attachment1 = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment2 = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment3 = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        _ = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!], visibility: .public)
        _ = try await Status.create(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], visibility: .followers)
        _ = try await Status.create(user: user, note: "Note 3", attachmentIds: [attachment3.stringId()!], visibility: .mentioned)

        // Act.
        let statuses = try SharedApplication.application().getResponse(
            as: .user(userName: "robinbrin", password: "p@ssword"),
            to: "/users/robinbrin/statuses",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )

        // Assert.
        XCTAssert(statuses.data.count == 3, "Statuses list should be returned.")
    }
    
    func testPublicStatusesListShouldBeReturnedToOtherUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wikibrin")
        let user2 = try await User.create(userName: "annabrin")

        let attachment1 = try await Attachment.create(user: user1)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment2 = try await Attachment.create(user: user1)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment3 = try await Attachment.create(user: user1)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        _ = try await Status.create(user: user1, note: "Note 1", attachmentIds: [attachment1.stringId()!], visibility: .public)
        _ = try await Status.create(user: user1, note: "Note 2", attachmentIds: [attachment2.stringId()!], visibility: .mentioned)
        _ = try await Status.create(user: user1, note: "Note 3", attachmentIds: [attachment3.stringId()!], visibility: .followers)

        // Act.
        let statuses = try SharedApplication.application().getResponse(
            as: .user(userName: user2.userName, password: "p@ssword"),
            to: "/users/\(user1.userName)/statuses",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )

        // Assert.
        XCTAssert(statuses.data.count == 1, "Public statuses list should be returned.")
    }
    
    func testPublicStatusesListShouldBeReturnedForUnauthorizedUser() async throws {
        // Arrange.
        let user = try await User.create(userName: "adrianbrin")

        let attachment1 = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment2 = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment3 = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        _ = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!], visibility: .public)
        _ = try await Status.create(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], visibility: .mentioned)
        _ = try await Status.create(user: user, note: "Note 3", attachmentIds: [attachment3.stringId()!], visibility: .followers)

        // Act.
        let statuses = try SharedApplication.application().getResponse(
            to: "/users/\(user.userName)/statuses",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )

        // Assert.
        XCTAssert(statuses.data.count == 1, "Public statuses list should be returned.")
    }
    
    func testStatusesListShouldNotBeReturnedForNotExistingUser() throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/users/@not-exists/statuses", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
