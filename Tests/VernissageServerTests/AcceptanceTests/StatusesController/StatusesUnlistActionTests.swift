//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class StatusesUnlistActionTests: CustomTestCase {
    func testStatusShouldBeUnlistedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "brostofiq")
        let user2 = try await User.create(userName: "ingatofiq")
        let user3 = try await User.create(userName: "romatofiq")
        try await user3.attach(role: Role.moderator)
        
        let attachment = try await Attachment.create(user: user1)
        let status = try await Status.create(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
        _ = try await UserStatus.create(type: .mention, user: user2, status: status)
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "romatofiq", password: "p@ssword"),
            to: "/statuses/\(status.requireID())/unlist",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userStatuses = try await UserStatus.getAll(for: status.requireID())
        XCTAssertTrue(userStatuses.count == 0, "Statuses should be deleted from user's timelines.")
    }
    
    func testForbiddenShouldbeReturnedForRegularUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "carinetofiq")
        _ = try await User.create(userName: "adametofiq")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "adametofiq", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/unlist",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testNotFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "maxetofiq")
        try await user1.attach(role: Role.moderator)
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "maxetofiq", password: "p@ssword"),
            to: "/statuses/123456789/unlist",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "moiqueetofiq")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/unlist",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
