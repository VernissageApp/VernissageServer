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
            let createdStatusDto = try application.getResponse(
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
            let response = try application.getErrorResponse(
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
            let response = try application.getErrorResponse(
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
            let response = try application.getErrorResponse(
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
            let response = try application.getErrorResponse(
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
