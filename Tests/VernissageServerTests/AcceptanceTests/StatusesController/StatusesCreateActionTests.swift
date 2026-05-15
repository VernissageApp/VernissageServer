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
    
    @Suite("Statuses (POST /statuses)", .serialized, .tags(.statuses))
    struct StatusesCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Status should be created for authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "martinbore")
            let attachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            let category = try await application.getCategory(name: "Street")
            
            let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    categoryId: category?.stringId(),
                                                    replyToStatusId: nil,
                                                    attachmentIds: [attachment.stringId()!])
            
            // Act.
            let createdStatusDto = try await application.getResponse(
                as: .user(userName: "martinbore", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: statusRequestDto,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(createdStatusDto.id != nil, "Status wasn't created.")
            #expect(statusRequestDto.note == createdStatusDto.note, "Status note should be correct.")
            #expect(statusRequestDto.visibility == createdStatusDto.visibility, "Status visibility should be correct.")
            #expect(statusRequestDto.sensitive == createdStatusDto.sensitive, "Status sensitive should be correct.")
            #expect(statusRequestDto.contentWarning == createdStatusDto.contentWarning, "Status contentWarning should be correct.")
            #expect(statusRequestDto.commentsDisabled == createdStatusDto.commentsDisabled, "Status commentsDisabled should be correct.")
            #expect(statusRequestDto.replyToStatusId == createdStatusDto.replyToStatusId, "Status replyToStatusId should be correct.")
            #expect(createdStatusDto.user.userName == "martinbore", "User should be returned.")
            #expect(createdStatusDto.category?.name == "Street", "Category should be correct.")
            #expect(createdStatusDto.publishedAt != nil, "Published at date should be set.")
        }
        
        @Test
        func `Attachments should be returned in correct order`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "jakyllbore")
            let attachment1 = try await application.createAttachment(user: user)
            let attachment2 = try await application.createAttachment(user: user)
            let attachment3 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment1, attachment2, attachment3])
            }
            let category = try await application.getCategory(name: "Street")
            
            let statusRequestDto = StatusRequestDto(note: "This is note with sorted attachmnents...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    categoryId: category?.stringId(),
                                                    replyToStatusId: nil,
                                                    attachmentIds: [attachment2.stringId()!, attachment3.stringId()!, attachment1.stringId()!])
            
            // Act.
            let createdStatusDto = try await application.getResponse(
                as: .user(userName: "jakyllbore", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: statusRequestDto,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(createdStatusDto.id != nil, "Status wasn't created.")
            #expect(createdStatusDto.attachments?.count == 3, "Status should contain two attachments")
            #expect(createdStatusDto.attachments?[0].id == attachment2.stringId(), "First attachment should be returned as first")
            #expect(createdStatusDto.attachments?[1].id == attachment3.stringId(), "Second attachment should be returned as second")
            #expect(createdStatusDto.attachments?[2].id == attachment1.stringId(), "Third attachment should be returned as third")
        }
        
        @Test
        func `Comment to status should be created for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "eliaszbore")
            let user2 = try await application.createUser(userName: "cindybore")
            
            let attachment1 = try await application.createAttachment(user: user1)
            let attachment2 = try await application.createAttachment(user: user2)
            
            defer {
                application.clearFiles(attachments: [attachment1, attachment2])
            }
            
            let status1 = try await application.createStatus(user: user1, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            let category = try await application.getCategory(name: "Street")
            
            let statusRequestDto = StatusRequestDto(note: "This is comment...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    categoryId: category?.stringId(),
                                                    replyToStatusId: status1.stringId(),
                                                    attachmentIds: [attachment2.stringId()!])
            
            // Act.
            let createdStatusDto = try await application.getResponse(
                as: .user(userName: "cindybore", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: statusRequestDto,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            let savedStatus = try await application.getStatus(id: createdStatusDto.id?.toId() ?? 0)
            #expect(savedStatus != nil, "Status have to be saved.")
            #expect(savedStatus?.$mainReplyToStatus.id == status1.id, "Main status id have to be saved for coments.")
            
            let parentStatus = try await application.getStatus(id: status1.id ?? 0)
            #expect(parentStatus?.repliesCount == 1, "Replies count of parent status have to be updated.")
        }
        
        @Test
        func `Status should not be created when limit of attachments is reached`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "irenebore")
            let attachment1 = try await application.createAttachment(user: user)
            let attachment2 = try await application.createAttachment(user: user)
            let attachment3 = try await application.createAttachment(user: user)
            let attachment4 = try await application.createAttachment(user: user)
            let attachment5 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment1, attachment2, attachment3, attachment4, attachment5])
            }
            let category = try await application.getCategory(name: "Street")
            
            let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    categoryId: category?.stringId(),
                                                    replyToStatusId: nil,
                                                    attachmentIds: [
                                                        attachment1.stringId()!,
                                                        attachment2.stringId()!,
                                                        attachment3.stringId()!,
                                                        attachment4.stringId()!,
                                                        attachment5.stringId()!
                                                    ])
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "irenebore", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: statusRequestDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test
        func `Status should not be created for unauthorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "chrisbore")
            let attachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    replyToStatusId: nil,
                                                    attachmentIds: [attachment.stringId()!])
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/statuses",
                method: .POST,
                data: statusRequestDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }

        @Test
        func `Status should not be created when account has been moved`() async throws {
            // Arrange.
            let sourceUser = try await application.createUser(userName: "movedstatussource")
            let targetUser = try await application.createUser(userName: "movedstatustarget")
            sourceUser.$movedTo.id = try targetUser.requireID()
            try await sourceUser.save(on: application.db)

            let attachment = try await application.createAttachment(user: sourceUser)
            defer {
                application.clearFiles(attachments: [attachment])
            }

            let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    replyToStatusId: nil,
                                                    attachmentIds: [attachment.stringId()!])

            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "movedstatussource", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: statusRequestDto
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(response.error.code == StatusError.accountHasBeenMoved.code, "Response error code should be accountHasBeenMoved.")
        }

        @Test
        func `Status should not be created when user email is not verified`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "unverifiedstatus", emailWasConfirmed: false)
            let otherUser = try await application.createUser(userName: "unverifiedstatusowner")
            let otherUserAttachment = try await application.createAttachment(user: otherUser)
            defer {
                application.clearFiles(attachments: [otherUserAttachment])
            }
            let parentStatus = try await application.createStatus(user: otherUser,
                                                                  note: "Parent status",
                                                                  attachmentIds: [otherUserAttachment.stringId()!])

            let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    replyToStatusId: parentStatus.stringId(),
                                                    attachmentIds: [])

            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "unverifiedstatus", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: statusRequestDto
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(response.error.code == StatusError.emailNotVerified.code, "Response error code should be emailNotVerified.")
        }
        
        @Test
        func `Status should not be created for attachments created by someone else`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "trendbore")
            let user = try await application.createUser(userName: "ronaldbore")
            let attachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    replyToStatusId: nil,
                                                    attachmentIds: [attachment.stringId()!])
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "trendbore", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: statusRequestDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Status should not be created when attachments and replyToStatusId are not applied`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "whitebore")
            let attachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    replyToStatusId: nil,
                                                    attachmentIds: [])
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "whitebore", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: statusRequestDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        }

        @Test
        func `Status should not be created too frequently when silent is false`() async throws {
            // Arrange.
            try await application.updateSetting(key: .minimumSecondsBetweenRegularStatuses, value: .int(60))
            try await application.updateSetting(key: .minimumSecondsBetweenSilentStatuses, value: .int(1))
            
            let user = try await application.createUser(userName: "floodnormaluser")
            let firstAttachment = try await application.createAttachment(user: user)
            let secondAttachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [firstAttachment, secondAttachment])
            }

            _ = try await application.createStatus(user: user,
                                                   note: "First status",
                                                   attachmentIds: [firstAttachment.stringId()!])

            let statusRequestDto = StatusRequestDto(note: "Second status",
                                                    visibility: .public,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    replyToStatusId: nil,
                                                    attachmentIds: [secondAttachment.stringId()!])

            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "floodnormaluser", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: statusRequestDto
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.tooManyRequests, "Response http status code should be too many requests (429).")
            #expect(response.error.code == StatusError.statusCreationTooFrequent(0).code, "Response error code should be statusCreationTooFrequent.")
            #expect(response.error.reason.contains("Please wait 60 seconds"), "Response reason should contain wait time in seconds.")
            
            // Rollback settings for other tests.
            try await application.updateSetting(key: .minimumSecondsBetweenRegularStatuses, value: .int(0))
            try await application.updateSetting(key: .minimumSecondsBetweenSilentStatuses, value: .int(0))
        }

        @Test
        func `Status should not be created too frequently when silent is true`() async throws {
            // Arrange.
            try await application.updateSetting(key: .minimumSecondsBetweenRegularStatuses, value: .int(60))
            try await application.updateSetting(key: .minimumSecondsBetweenSilentStatuses, value: .int(1))
            
            let user = try await application.createUser(userName: "floodsilentuser")
            let firstAttachment = try await application.createAttachment(user: user)
            let secondAttachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [firstAttachment, secondAttachment])
            }

            let firstStatusRequestDto = StatusRequestDto(note: "First silent status",
                                                         visibility: .quietPublic,
                                                         sensitive: false,
                                                         contentWarning: nil,
                                                         commentsDisabled: false,
                                                         replyToStatusId: nil,
                                                         attachmentIds: [firstAttachment.stringId()!])

            _ = try await application.getResponse(
                as: .user(userName: "floodsilentuser", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: firstStatusRequestDto,
                decodeTo: StatusDto.self
            )

            let secondStatusRequestDto = StatusRequestDto(note: "Second silent status",
                                                          visibility: .quietPublic,
                                                          sensitive: false,
                                                          contentWarning: nil,
                                                          commentsDisabled: false,
                                                          replyToStatusId: nil,
                                                          attachmentIds: [secondAttachment.stringId()!])

            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "floodsilentuser", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: secondStatusRequestDto
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.tooManyRequests, "Response http status code should be too many requests (429).")
            #expect(response.error.code == StatusError.statusCreationTooFrequent(0).code, "Response error code should be statusCreationTooFrequent.")
            #expect(response.error.reason.contains("Please wait 1 second"), "Response reason should contain wait time in seconds.")
            
            // Rollback settings for other tests.
            try await application.updateSetting(key: .minimumSecondsBetweenRegularStatuses, value: .int(0))
            try await application.updateSetting(key: .minimumSecondsBetweenSilentStatuses, value: .int(0))
        }
        
        @Test
        func `Comments should be created without anti-flood time limit`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "fastcommentuser")
            let parentAttachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [parentAttachment])
            }
            
            let parentStatus = try await application.createStatus(user: user,
                                                                  note: "Parent status",
                                                                  attachmentIds: [parentAttachment.stringId()!])
            
            let firstCommentRequestDto = StatusRequestDto(note: "First comment",
                                                          visibility: .public,
                                                          sensitive: false,
                                                          contentWarning: nil,
                                                          commentsDisabled: false,
                                                          replyToStatusId: parentStatus.stringId(),
                                                          attachmentIds: [])
            
            let secondCommentRequestDto = StatusRequestDto(note: "Second comment",
                                                           visibility: .public,
                                                           sensitive: false,
                                                           contentWarning: nil,
                                                           commentsDisabled: false,
                                                           replyToStatusId: parentStatus.stringId(),
                                                           attachmentIds: [])
            
            // Act.
            let firstComment = try await application.getResponse(
                as: .user(userName: "fastcommentuser", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: firstCommentRequestDto,
                decodeTo: StatusDto.self
            )
            
            let secondComment = try await application.getResponse(
                as: .user(userName: "fastcommentuser", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: secondCommentRequestDto,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(firstComment.id != nil, "First comment should be created.")
            #expect(secondComment.id != nil, "Second comment should be created.")
        }
        
        @Test
        func `Status should not be created when attachments are not applied`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "georgebore")
            let attachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    replyToStatusId: "12332112",
                                                    attachmentIds: [])
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "georgebore", password: "p@ssword"),
                to: "/statuses",
                method: .POST,
                data: statusRequestDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
