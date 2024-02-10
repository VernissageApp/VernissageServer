//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class StatusesFeatureActionTests: CustomTestCase {
    func testStatusShouldBeFeaturedForModerator() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "roxyfokimo")
        let user2 = try await User.create(userName: "tobyfokimo")
        try await user2.attach(role: Role.moderator)
        
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusDto = try SharedApplication.application().getResponse(
            as: .user(userName: "tobyfokimo", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/feature",
            method: .POST,
            decodeTo: StatusDto.self
        )
        
        // Assert.
        XCTAssert(statusDto.id != nil, "Status wasn't created.")
        XCTAssertEqual(statusDto.featured, true, "Status should be marked as featured.")
    }
    
    func testForbiddenShouldbeReturnedForRegularUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "carinefokimo")
        _ = try await User.create(userName: "adamefokimo")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "adamefokimo", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/feature",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testNotFoundShouldBeReturnedForStatusWithMentionedVisibility() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "brosefokimo")
        let user2 = try await User.create(userName: "ingaefokimo")
        try await user2.attach(role: Role.moderator)
        
        let attachment = try await Attachment.create(user: user1)
        let status = try await Status.create(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "ingaefokimo", password: "p@ssword"),
            to: "/statuses/\(status.requireID())/feature",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testNotFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "maxefokimo")
        try await user1.attach(role: Role.moderator)
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "maxefokimo", password: "p@ssword"),
            to: "/statuses/123456789/feature",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "moiqueefokimo")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/feature",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

