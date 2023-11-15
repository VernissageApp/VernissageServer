//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class StatusesReadActionTests: CustomTestCase {

    func testStatusShouldBeReturnedForUnauthorized() async throws {

        // Arrange.
        let user = try await User.create(userName: "robinhoower")
        let attachment1 = try await Attachment.create(user: user)
        defer {
            Status.clearFiles(attachments: [attachment1])
        }
        
        let status = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])

        // Act.
        let statusDto = try SharedApplication.application().getResponse(
            to: "/statuses/\(status.requireID())",
            method: .GET,
            decodeTo: StatusDto.self
        )

        // Assert.
        XCTAssertNotNil(statusDto, "Status should be returned.")
        XCTAssertEqual(status.note, statusDto.note, "Status note should be returned.")
        XCTAssertEqual(statusDto.user.userName, "robinhoower", "User should be returned.")
    }
    
    func testOtherUserPrivateStatusShouldNotBeReturned() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "evelynhoower")
        let user2 = try await User.create(userName: "fredhoower")
        
        let attachment1 = try await Attachment.create(user: user1)
        defer {
            Status.clearFiles(attachments: [attachment1])
        }
                        
        let status = try await Status.create(user: user1, note: "PRIVATE 1", attachmentIds: [attachment1.stringId()!], visibility: .mentioned)

        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: user2.userName, password: "p@ssword"),
            to: "/statuses/\(status.requireID())",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testOwnPrivateStatusShouldBeReturned() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "stanhoower")
        let attachment1 = try await Attachment.create(user: user1)
        defer {
            Status.clearFiles(attachments: [attachment1])
        }
                        
        let status = try await Status.create(user: user1, note: "PRIVATE 1", attachmentIds: [attachment1.stringId()!], visibility: .mentioned)

        // Act.
        let statusDto = try SharedApplication.application().getResponse(
            as: .user(userName: user1.userName, password: "p@ssword"),
            to: "/statuses/\(status.requireID())",
            method: .GET,
            decodeTo: StatusDto.self
        )

        // Assert.
        XCTAssertNotNil(statusDto, "Status should be returned.")
    }
}
