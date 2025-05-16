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
        
        @Test("Status should be created for authorized user")
        func statusShouldBeCreatedForAuthorizedUser() async throws {
            
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
        
        @Test("Attachments should be returned in correct order")
        func attachmentsShouldBeReturnedInCorrectOrder() async throws {
            
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
        
        @Test("Comment to status should be created for authorized user")
        func commentToStatusShouldBeCreatedForAuthorizedUser() async throws {
            
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
        
        @Test("Status should not be created for unauthorized user")
        func statusShouldNotBeCreatedForUnauthorizedUser() async throws {
            
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
        
        @Test("Status should not be created for attachments created by someone else")
        func statusShouldNotBeCreatedForAttachmentsCreatedBySomeoneElse() async throws {
            
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
        
        @Test("Status should not be created when attachments and replyToStatusId are not applied")
        func statusShouldNotBeCreatedWhenAttachmentsAndReplyStatusIdAreNotApplied() async throws {
            
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
        
        @Test("Status should not be created when attachments are not applied")
        func statusShouldNotBeCreatedWhenAttachmentsAreNotApplied() async throws {
            
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
