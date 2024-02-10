//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class StatusesCreateActionTests: CustomTestCase {
    
    func testStatusShouldBeCreatedForAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "martinbore")
        let attachment = try await Attachment.create(user: user)
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        let category = try await Category.get(name: "Street")
        
        let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                visibility: .followers,
                                                sensitive: false,
                                                contentWarning: nil,
                                                commentsDisabled: false,
                                                categoryId: category?.stringId(),
                                                replyToStatusId: nil,
                                                attachmentIds: [attachment.stringId()!])
        
        // Act.
        let createdStatusDto = try SharedApplication.application().getResponse(
            as: .user(userName: "martinbore", password: "p@ssword"),
            to: "/statuses",
            method: .POST,
            data: statusRequestDto,
            decodeTo: StatusDto.self
        )
        
        // Assert.
        XCTAssert(createdStatusDto.id != nil, "Status wasn't created.")
        XCTAssertEqual(statusRequestDto.note, createdStatusDto.note, "Status note should be correct.")
        XCTAssertEqual(statusRequestDto.visibility, createdStatusDto.visibility, "Status visibility should be correct.")
        XCTAssertEqual(statusRequestDto.sensitive, createdStatusDto.sensitive, "Status sensitive should be correct.")
        XCTAssertEqual(statusRequestDto.contentWarning, createdStatusDto.contentWarning, "Status contentWarning should be correct.")
        XCTAssertEqual(statusRequestDto.commentsDisabled, createdStatusDto.commentsDisabled, "Status commentsDisabled should be correct.")
        XCTAssertEqual(statusRequestDto.replyToStatusId, createdStatusDto.replyToStatusId, "Status replyToStatusId should be correct.")
        XCTAssertEqual(createdStatusDto.user.userName, "martinbore", "User should be returned.")
        XCTAssertEqual(createdStatusDto.category?.name, "Street", "Category should be correct.")
    }
    
    func testStatusShouldNotBeCreatedForUnauthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "chrisbore")
        let attachment = try await Attachment.create(user: user)
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                visibility: .followers,
                                                sensitive: false,
                                                contentWarning: nil,
                                                commentsDisabled: false,
                                                replyToStatusId: nil,
                                                attachmentIds: [attachment.stringId()!])
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            to: "/statuses",
            method: .POST,
            data: statusRequestDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testStatusShouldNotBeCreatedForAttachmentsCreatedBySomeoneElse() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "trendbore")
        let user = try await User.create(userName: "ronaldbore")
        let attachment = try await Attachment.create(user: user)
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                visibility: .followers,
                                                sensitive: false,
                                                contentWarning: nil,
                                                commentsDisabled: false,
                                                replyToStatusId: nil,
                                                attachmentIds: [attachment.stringId()!])
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "trendbore", password: "p@ssword"),
            to: "/statuses",
            method: .POST,
            data: statusRequestDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testStatusShouldNotBeCreatedWhenAttachmentsAndReplyStatusIdAreNotApplied() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "whitebore")
        let attachment = try await Attachment.create(user: user)
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                visibility: .followers,
                                                sensitive: false,
                                                contentWarning: nil,
                                                commentsDisabled: false,
                                                replyToStatusId: nil,
                                                attachmentIds: [])
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "whitebore", password: "p@ssword"),
            to: "/statuses",
            method: .POST,
            data: statusRequestDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
    }
    
    func testStatusShouldNotBeCreatedWhenAttachmentsAreNotApplied() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "georgebore")
        let attachment = try await Attachment.create(user: user)
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                visibility: .followers,
                                                sensitive: false,
                                                contentWarning: nil,
                                                commentsDisabled: false,
                                                replyToStatusId: "12332112",
                                                attachmentIds: [])
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "georgebore", password: "p@ssword"),
            to: "/statuses",
            method: .POST,
            data: statusRequestDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
