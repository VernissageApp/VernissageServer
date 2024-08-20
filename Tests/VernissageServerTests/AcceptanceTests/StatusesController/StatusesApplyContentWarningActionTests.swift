//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class StatusesApplyContentWarningActionTests: CustomTestCase {
    func testContentWarningShouldBeAddedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "brosgeblix")
        let user3 = try await User.create(userName: "romageblix")
        try await user3.attach(role: Role.moderator)
        
        let attachment = try await Attachment.create(user: user1)
        let status = try await Status.create(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "romageblix", password: "p@ssword"),
            to: "/statuses/\(status.requireID())/apply-content-warning",
            method: .POST,
            body: ContentWarningDto(contentWarning: "This is rude.")
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let statusAfterUpdate = try await Status.get(id: status.requireID())
        XCTAssertEqual(statusAfterUpdate?.contentWarning, "This is rude.", "Content warning should be applied.")
    }
    
    func testForbiddenShouldbeReturnedForRegularUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "carinegeblix")
        _ = try await User.create(userName: "adamegeblix")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "adamegeblix", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/apply-content-warning",
            method: .POST,
            body: ContentWarningDto(contentWarning: "This is rude.")
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testNotFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "maxegeblix")
        try await user1.attach(role: Role.moderator)
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "maxegeblix", password: "p@ssword"),
            to: "/statuses/123456789/apply-content-warning",
            method: .POST,
            data: ContentWarningDto(contentWarning: "This is rude.")
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "moiqueegeblix")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/apply-content-warning",
            method: .POST,
            data: ContentWarningDto(contentWarning: "This is rude.")
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
