//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class StatusesUnfeatureActionTests: CustomTestCase {
    func testStatusShouldBeUnfeaturedForModerator() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "maximrojon")
        let user2 = try await User.create(userName: "roxyrojon")
        try await user2.attach(role: Role.moderator)
        
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        _ = try await FeaturedStatus.create(user: user2, status: statuses.first!)
        
        // Act.
        let statusDto = try SharedApplication.application().getResponse(
            as: .user(userName: "roxyrojon", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/unfeature",
            method: .POST,
            decodeTo: StatusDto.self
        )
        
        // Assert.
        XCTAssert(statusDto.id != nil, "Status wasn't created.")
        XCTAssertEqual(statusDto.featured, false, "Status should be marked as unfeatured.")
    }
    
    func testForbiddenShouldbeReturnedForRegularUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "carinrojon")
        let user2 = try await User.create(userName: "adamrojon")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        _ = try await FeaturedStatus.create(user: user2, status: statuses.first!)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "adamrojon", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/unfeature",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
        
    func testNotFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "maxrojon")
        try await user1.attach(role: Role.moderator)
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "maxrojon", password: "p@ssword"),
            to: "/statuses/123456789/unfeature",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "moiquerojon")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/unfeature",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

