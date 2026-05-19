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
    
    @Suite("Users (GET /users/:username/statuses)", .serialized, .tags(.users))
    struct UsersStatusesActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `All statuses list should be returned for owner`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "robinbrin")
            
            let attachment1 = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment1.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment1.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let attachment2 = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment2.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment2.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let attachment3 = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment3.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment3.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            _ = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!], visibility: .public)
            _ = try await application.createStatus(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], visibility: .followers)
            _ = try await application.createStatus(user: user, note: "Note 3", attachmentIds: [attachment3.stringId()!], visibility: .mentioned)
            
            // Act.
            let statuses = try await application.getResponse(
                as: .user(userName: "robinbrin", password: "p@ssword"),
                to: "/users/robinbrin/statuses",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statuses.data.count == 3, "Statuses list should be returned.")
        }
        
        @Test
        func `Public and quiet public statuses list should be returned to other user`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wikibrin")
            let user2 = try await application.createUser(userName: "annabrin")
            
            let attachment1 = try await application.createAttachment(user: user1)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment1.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment1.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let attachment2 = try await application.createAttachment(user: user1)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment2.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment2.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let attachment3 = try await application.createAttachment(user: user1)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment3.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment3.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }

            let attachment4 = try await application.createAttachment(user: user1)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment4.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)

                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment4.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            _ = try await application.createStatus(user: user1, note: "Note 1", attachmentIds: [attachment1.stringId()!], visibility: .public)
            _ = try await application.createStatus(user: user1, note: "Note 2", attachmentIds: [attachment2.stringId()!], visibility: .quietPublic)
            _ = try await application.createStatus(user: user1, note: "Note 3", attachmentIds: [attachment3.stringId()!], visibility: .mentioned)
            _ = try await application.createStatus(user: user1, note: "Note 4", attachmentIds: [attachment4.stringId()!], visibility: .followers)
            
            // Act.
            let statuses = try await application.getResponse(
                as: .user(userName: user2.userName, password: "p@ssword"),
                to: "/users/\(user1.userName)/statuses",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statuses.data.count == 2, "Public and quiet public statuses list should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "Note 1" }) == true, "Public status should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "Note 2" }) == true, "Quiet public status should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "Note 3" }) == false, "Mentioned status should not be returned.")
            #expect(statuses.data.contains(where: { $0.note == "Note 4" }) == false, "Followers status should not be returned.")
        }
        
        @Test
        func `Public and quiet public statuses list should be returned for unauthorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "adrianbrin")
            
            let attachment1 = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment1.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment1.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let attachment2 = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment2.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment2.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let attachment3 = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment3.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment3.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }

            let attachment4 = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment4.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)

                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment4.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            _ = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!], visibility: .public)
            _ = try await application.createStatus(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], visibility: .quietPublic)
            _ = try await application.createStatus(user: user, note: "Note 3", attachmentIds: [attachment3.stringId()!], visibility: .mentioned)
            _ = try await application.createStatus(user: user, note: "Note 4", attachmentIds: [attachment4.stringId()!], visibility: .followers)
            
            // Act.
            let statuses = try await application.getResponse(
                to: "/users/\(user.userName)/statuses",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statuses.data.count == 2, "Public and quiet public statuses list should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "Note 1" }) == true, "Public status should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "Note 2" }) == true, "Quiet public status should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "Note 3" }) == false, "Mentioned status should not be returned.")
            #expect(statuses.data.contains(where: { $0.note == "Note 4" }) == false, "Followers status should not be returned.")
        }

        @Test
        func `Only pinned statuses should be returned when onlyPinned is set`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "onlypinnedowner")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Only Pinned", amount: 3)
            defer {
                application.clearFiles(attachments: attachments)
            }

            let newestPinnedAt = Date()
            let olderPinnedAt = newestPinnedAt.addingTimeInterval(-120)

            statuses[0].pinnedAt = olderPinnedAt
            statuses[2].pinnedAt = newestPinnedAt
            try await statuses[0].save(on: application.db)
            try await statuses[2].save(on: application.db)

            // Act.
            let response = try await application.getResponse(
                as: .user(userName: "onlypinnedowner", password: "p@ssword"),
                to: "/users/onlypinnedowner/statuses?onlyPinned=true",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )

            // Assert.
            #expect(response.data.count == 2, "Only pinned statuses should be returned.")
            #expect(response.data[0].id == statuses[2].stringId(), "Newest pinned status should be first.")
            #expect(response.data[1].id == statuses[0].stringId(), "Oldest pinned status should be second.")
            #expect(response.data[0].pinnedAt != nil, "Pinned status should have pinnedAt value.")
            #expect(response.data[1].pinnedAt != nil, "Pinned status should have pinnedAt value.")
        }

        @Test
        func `Profile statuses should keep createdAt order when onlyPinned is not set`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "pinnedfirstowner")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Pinned First", amount: 3)
            defer {
                application.clearFiles(attachments: attachments)
            }

            statuses[1].pinnedAt = Date()
            try await statuses[1].save(on: application.db)

            // Act.
            let response = try await application.getResponse(
                as: .user(userName: "pinnedfirstowner", password: "p@ssword"),
                to: "/users/pinnedfirstowner/statuses",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )

            // Assert.
            #expect(response.data.count == 3, "Statuses list should be returned.")
            #expect(response.data.first?.id == statuses[2].stringId(), "Newest status should be returned first.")
        }
        
        @Test
        func `Statuses list should not be returned for not existing user`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/users/@not-exists/statuses", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
