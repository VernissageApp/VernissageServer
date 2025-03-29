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
    
    @Suite("Statuses (DELETE /statuses/:id)", .serialized, .tags(.statuses))
    struct StatusesDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Status should be deleted for authorized user")
        func statusShouldBeDeletedForAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinworth")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Deleted", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "robinworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Status should be deleted.")
        }
        
        @Test("Status should be deleted by administrator")
        func statusShouldBeDeletedByAdministrator() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "adamworth")
            
            let administrator = try await application.createUser(userName: "tobiaszworth")
            try await application.attach(user: administrator, role: Role.administrator)
            
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Delete Administrator", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "tobiaszworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Status should be deleted.")
        }
        
        @Test("Status should be deleted by moderator")
        func statusShouldBeDeletedByModerator() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "romanekworth")
            
            let moderator = try await application.createUser(userName: "karolzworth")
            try await application.attach(user: moderator, role: Role.moderator)
            
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Deleted Moderator", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "karolzworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Status should be deleted.")
        }
        
        @Test("Status and his reblogs should be deleted for authorized user")
        func statusAndHisReblogsShouldBeDeletedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinworth")
            let user2 = try await application.createUser(userName: "gorgiworth")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Deleted Reblogs", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let reblog = try await application.reblogStatus(user: user2, status: statuses.first!)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "carinworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Orginal status should be deleted.")
            
            let reblogStatusFromDatabase = try? await application.getStatus(id: reblog.requireID())
            #expect(reblogStatusFromDatabase == nil, "Reblog status should be deleted.")
        }
        
        @Test("Status and his replies should be deleted for authorized user")
        func statusAndHisRepliesShouldBeDeletedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "maxworth")
            let user2 = try await application.createUser(userName: "benworth")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Delete Replies", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let status2A = try await application.replyStatus(user: user2, comment: "This is reply for status 1", status: statuses.first!)
            let status2B = try await application.replyStatus(user: user2, comment: "This is reply for status 1", status: statuses.first!)
            let status3A = try await application.replyStatus(user: user2, comment: "This is reply for status 2A", status: status2A)
            let status3B = try await application.replyStatus(user: user2, comment: "This is reply for status 2B", status: status2B)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "maxworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Orginal status should be deleted.")
            
            let status2AFromDatabase = try? await application.getStatus(id: status2A.requireID())
            #expect(status2AFromDatabase == nil, "Reply status2A status should be deleted.")
            
            let status2BFromDatabase = try? await application.getStatus(id: status2B.requireID())
            #expect(status2BFromDatabase == nil, "Reply status2B status should be deleted.")
            
            let status3AFromDatabase = try? await application.getStatus(id: status3A.requireID())
            #expect(status3AFromDatabase == nil, "Reply status3A status should be deleted.")
            
            let status3BFromDatabase = try? await application.getStatus(id: status3B.requireID())
            #expect(status3BFromDatabase == nil, "Reply status3B status should be deleted.")
        }
        
        @Test("Status and his hashtags should be deleted for authorized user")
        func statusAndHisHashtagsShouldBeDeletedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "richardworth")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note #photo #blackandwhite", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "richardworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Orginal status should be deleted.")
        }
        
        @Test("Status and his mentions should be deleted for authorized user")
        func statusAndHisMentionsShouldBeDeletedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "marecworth")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note @marcin @kamila", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "marecworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Orginal status should be deleted.")
        }
        
        @Test("Reply count should be recalculated when deleting comment")
        func replyCountShouldBeRecalculatedWhenDeletingCommnent() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "ninaworth")
            let user2 = try await application.createUser(userName: "anielkaworth")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Delete Replies", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let comment = try await application.replyStatus(user: user2, comment: "This is reply for status 1", status: statuses.first!)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "anielkaworth", password: "p@ssword"),
                to: "/statuses/\(comment.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let parentStatus = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(parentStatus?.repliesCount == 0, "Replies count should be recalculated.")
        }
        
        @Test("Status should not be deleted for unauthorized user")
        func statusShouldNotBeDeletedForUnauthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "erikworth")
            let attachment1 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment1])
            }
            
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            
            // Act.
            let response = try await application.sendRequest(
                to: "/statuses/\(status.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Status should not be deleted for status created by other user")
        func statusShouldNotBeDeletedForStatusCreatedByOtherUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maciasworth")
            let user = try await application.createUser(userName: "georgeworth")
            let attachment1 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment1])
            }
            
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "maciasworth", password: "p@ssword"),
                to: "/statuses/\(status.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
    }
}
