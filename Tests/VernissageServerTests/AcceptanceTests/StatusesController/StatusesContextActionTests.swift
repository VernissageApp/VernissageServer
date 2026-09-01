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
    
    @Suite("Statuses (GET /statuses/:id/context)", .serialized, .tags(.statuses))
    struct StatusesContextActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Status context should be returned for user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robintopiq")
            
            let attachment1 = try await application.createAttachment(user: user)
            let attachment2 = try await application.createAttachment(user: user)
            let attachment3 = try await application.createAttachment(user: user)
            let attachment4 = try await application.createAttachment(user: user)
            let attachment5 = try await application.createAttachment(user: user)
            
            let status1 = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            let status2 = try await application.createStatus(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], replyToStatusId: status1.stringId())
            let status3 = try await application.createStatus(user: user, note: "Note 3", attachmentIds: [attachment3.stringId()!], replyToStatusId: status2.stringId())
            let status4 = try await application.createStatus(user: user, note: "Note 4", attachmentIds: [attachment4.stringId()!], replyToStatusId: status3.stringId())
            let status5 = try await application.createStatus(user: user, note: "Note 5", attachmentIds: [attachment5.stringId()!], replyToStatusId: status3.stringId())
            
            defer {
                application.clearFiles(attachments: [attachment1, attachment2, attachment3, attachment4, attachment5])
            }
            
            // Act.
            let statusContextDto = try await application.getResponse(
                as: .user(userName: "robintopiq", password: "p@ssword"),
                to: "/statuses/\(status3.requireID())/context",
                method: .GET,
                decodeTo: StatusContextDto.self
            )
            
            // Assert.
            #expect(statusContextDto.ancestors.count > 0, "Status ancestors context should be returned.")
            #expect(statusContextDto.descendants.count > 0, "Status descendants context should be returned.")
            #expect(status1.stringId() == statusContextDto.ancestors[0].id, "First status ancestor should be returned.")
            #expect(status2.stringId() == statusContextDto.ancestors[1].id, "Second status ancestor should be returned.")
            #expect(status4.stringId() == statusContextDto.descendants[0].id, "First status descendant should be returned.")
            #expect(status5.stringId() == statusContextDto.descendants[1].id, "Second status descendant should be returned.")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized not public status`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "komatopiq")
            
            let attachment1 = try await application.createAttachment(user: user)
            let attachment2 = try await application.createAttachment(user: user)
            
            let status1 = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!], visibility: .mentioned)
            let status2 = try await application.createStatus(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], visibility: .mentioned, replyToStatusId: status1.stringId())
            
            defer {
                application.clearFiles(attachments: [attachment1, attachment2])
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(status2.requireID())/context",
                method: .GET
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test
        func `Status context should be returned for not authorized user and public status`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "temontopiq")
            
            let attachment1 = try await application.createAttachment(user: user)
            let attachment2 = try await application.createAttachment(user: user)
            
            let status1 = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            let status2 = try await application.createStatus(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], replyToStatusId: status1.stringId())
            
            defer {
                application.clearFiles(attachments: [attachment1, attachment2])
            }
            
            // Act.
            let statusContextDto = try await application.getResponse(
                to: "/statuses/\(status2.requireID())/context",
                method: .GET,
                decodeTo: StatusContextDto.self
            )
            
            // Assert.
            #expect(statusContextDto.ancestors.count > 0, "Status ancestors context should be returned.")
        }

        @Test
        func `Status context should contain only comments visible to requesting user`() async throws {
            // Arrange.
            let rootOwner = try await application.createUser(userName: "contextvisibilityroot")
            let reader = try await application.createUser(userName: "contextvisibilityreader")
            let publicAuthor = try await application.createUser(userName: "contextvisibilitypublic")
            let mentionedAuthor = try await application.createUser(userName: "contextvisibilitymentioned")
            let followedAuthor = try await application.createUser(userName: "contextvisibilityfollowed")
            let hiddenAuthor = try await application.createUser(userName: "contextvisibilityhidden")

            let rootAttachment = try await application.createAttachment(user: rootOwner)
            defer {
                application.clearFiles(attachments: [rootAttachment])
            }
            let rootAttachmentId = try #require(rootAttachment.stringId())
            let root = try await application.createStatus(user: rootOwner, note: "ROOT", attachmentIds: [rootAttachmentId])
            let publicComment = try await application.createStatus(user: publicAuthor,
                                                                   note: "PUBLIC COMMENT",
                                                                   attachmentIds: [],
                                                                   replyToStatusId: root.stringId())
            let quietPublicComment = try await application.createStatus(user: publicAuthor,
                                                                        note: "QUIET PUBLIC COMMENT",
                                                                        attachmentIds: [],
                                                                        visibility: .quietPublic,
                                                                        replyToStatusId: root.stringId())
            let mentionedComment = try await application.createStatus(user: mentionedAuthor,
                                                                      note: "MENTIONED COMMENT",
                                                                      attachmentIds: [],
                                                                      visibility: .mentioned,
                                                                      replyToStatusId: root.stringId())
            let hiddenMentionedComment = try await application.createStatus(user: hiddenAuthor,
                                                                            note: "HIDDEN MENTIONED COMMENT",
                                                                            attachmentIds: [],
                                                                            visibility: .mentioned,
                                                                            replyToStatusId: root.stringId())
            let followersComment = try await application.createStatus(user: followedAuthor,
                                                                      note: "FOLLOWERS COMMENT",
                                                                      attachmentIds: [],
                                                                      visibility: .followers,
                                                                      replyToStatusId: root.stringId())
            let hiddenFollowersComment = try await application.createStatus(user: hiddenAuthor,
                                                                            note: "HIDDEN FOLLOWERS COMMENT",
                                                                            attachmentIds: [],
                                                                            visibility: .followers,
                                                                            replyToStatusId: root.stringId())
            let mentionedFollowersComment = try await application.createStatus(user: hiddenAuthor,
                                                                               note: "FOLLOWERS COMMENT MENTIONING READER",
                                                                               attachmentIds: [],
                                                                               visibility: .followers,
                                                                               replyToStatusId: root.stringId())
            let publicReplyToHiddenComment = try await application.createStatus(user: hiddenAuthor,
                                                                                note: "PUBLIC REPLY TO HIDDEN COMMENT",
                                                                                attachmentIds: [],
                                                                                replyToStatusId: hiddenFollowersComment.stringId())

            _ = try await application.createUserStatus(type: .mention, user: reader, status: mentionedComment)
            _ = try await application.createUserStatus(type: .mention, user: reader, status: mentionedFollowersComment)
            _ = try await application.createFollow(sourceId: reader.requireID(), targetId: followedAuthor.requireID(), approved: true)

            let publicCommentId = try #require(publicComment.stringId())
            let quietPublicCommentId = try #require(quietPublicComment.stringId())
            let mentionedCommentId = try #require(mentionedComment.stringId())
            let hiddenMentionedCommentId = try #require(hiddenMentionedComment.stringId())
            let followersCommentId = try #require(followersComment.stringId())
            let hiddenFollowersCommentId = try #require(hiddenFollowersComment.stringId())
            let mentionedFollowersCommentId = try #require(mentionedFollowersComment.stringId())
            let publicReplyToHiddenCommentId = try #require(publicReplyToHiddenComment.stringId())

            // Act.
            let authorizedContext = try await application.getResponse(
                as: .user(userName: reader.userName, password: "p@ssword"),
                to: "/statuses/\(root.requireID())/context",
                method: .GET,
                decodeTo: StatusContextDto.self
            )
            let anonymousContext = try await application.getResponse(
                to: "/statuses/\(root.requireID())/context",
                method: .GET,
                decodeTo: StatusContextDto.self
            )

            // Assert.
            let authorizedIds = Set(authorizedContext.descendants.compactMap(\.id))
            #expect(authorizedIds.contains(publicCommentId), "Public comment should be returned.")
            #expect(authorizedIds.contains(quietPublicCommentId), "Quiet public comment should be returned.")
            #expect(authorizedIds.contains(mentionedCommentId), "Comment mentioning the reader should be returned.")
            #expect(authorizedIds.contains(followersCommentId), "Comment from a followed user should be returned.")
            #expect(authorizedIds.contains(mentionedFollowersCommentId), "Followers-only comment mentioning the reader should be returned.")
            #expect(authorizedIds.contains(publicReplyToHiddenCommentId), "Public reply below a hidden comment should be returned.")
            #expect(authorizedIds.contains(hiddenMentionedCommentId) == false, "Comment not mentioning the reader should be hidden.")
            #expect(authorizedIds.contains(hiddenFollowersCommentId) == false, "Followers-only comment from a non-followed user should be hidden.")

            let anonymousIds = Set(anonymousContext.descendants.compactMap(\.id))
            #expect(anonymousIds == Set([publicCommentId, quietPublicCommentId, publicReplyToHiddenCommentId]), "Anonymous context should contain only public comments.")
        }
        
        @Test
        func `Not found should be returned if status not exists`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maxtopiq")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxtopiq", password: "p@ssword"),
                to: "/statuses/123456789/context",
                method: .GET
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Bad request should be returned if status id is not integer`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "annatopiq")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "annatopiq", password: "p@ssword"),
                to: "/statuses/aaa/context",
                method: .GET
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        }
    }
}
