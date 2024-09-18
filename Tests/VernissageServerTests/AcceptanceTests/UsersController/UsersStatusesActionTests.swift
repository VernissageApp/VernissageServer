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

@Suite("GET /:username/statuses", .serialized, .tags(.users))
struct UsersStatusesActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("All statuses list should be returned for owner")
    func allStatusesListShouldBeReturnedForOwner() async throws {
        // Arrange.
        let user = try await application.createUser(userName: "robinbrin")

        let attachment1 = try await application.createAttachment(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment2 = try await application.createAttachment(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment3 = try await application.createAttachment(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        _ = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!], visibility: .public)
        _ = try await application.createStatus(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], visibility: .followers)
        _ = try await application.createStatus(user: user, note: "Note 3", attachmentIds: [attachment3.stringId()!], visibility: .mentioned)

        // Act.
        let statuses = try application.getResponse(
            as: .user(userName: "robinbrin", password: "p@ssword"),
            to: "/users/robinbrin/statuses",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )

        // Assert.
        #expect(statuses.data.count == 3, "Statuses list should be returned.")
    }
    
    @Test("Public statuses list should be returned to other user")
    func publicStatusesListShouldBeReturnedToOtherUser() async throws {
        // Arrange.
        let user1 = try await application.createUser(userName: "wikibrin")
        let user2 = try await application.createUser(userName: "annabrin")

        let attachment1 = try await application.createAttachment(user: user1)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment2 = try await application.createAttachment(user: user1)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment3 = try await application.createAttachment(user: user1)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        _ = try await application.createStatus(user: user1, note: "Note 1", attachmentIds: [attachment1.stringId()!], visibility: .public)
        _ = try await application.createStatus(user: user1, note: "Note 2", attachmentIds: [attachment2.stringId()!], visibility: .mentioned)
        _ = try await application.createStatus(user: user1, note: "Note 3", attachmentIds: [attachment3.stringId()!], visibility: .followers)

        // Act.
        let statuses = try application.getResponse(
            as: .user(userName: user2.userName, password: "p@ssword"),
            to: "/users/\(user1.userName)/statuses",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )

        // Assert.
        #expect(statuses.data.count == 1, "Public statuses list should be returned.")
    }
    
    @Test("Public statuses list should be returned for unauthorized user")
    func publicStatusesListShouldBeReturnedForUnauthorizedUser() async throws {
        // Arrange.
        let user = try await application.createUser(userName: "adrianbrin")

        let attachment1 = try await application.createAttachment(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment1.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment2 = try await application.createAttachment(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment2.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let attachment3 = try await application.createAttachment(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment3.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        _ = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!], visibility: .public)
        _ = try await application.createStatus(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], visibility: .mentioned)
        _ = try await application.createStatus(user: user, note: "Note 3", attachmentIds: [attachment3.stringId()!], visibility: .followers)

        // Act.
        let statuses = try application.getResponse(
            to: "/users/\(user.userName)/statuses",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )

        // Assert.
        #expect(statuses.data.count == 1, "Public statuses list should be returned.")
    }
    
    @Test("Statuses list should not be returned for not existing user")
    func statusesListShouldNotBeReturnedForNotExistingUser() throws {
        // Act.
        let response = try application.sendRequest(to: "/users/@not-exists/statuses", method: .GET)

        // Assert.
        #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
