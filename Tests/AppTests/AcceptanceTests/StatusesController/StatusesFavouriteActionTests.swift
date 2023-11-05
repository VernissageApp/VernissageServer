//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class StatusesFavouriteActionTests: CustomTestCase {
    func testStatusShouldBeFavouritedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "carintofi")
        _ = try await User.create(userName: "adamtofi")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusDto = try SharedApplication.application().getResponse(
            as: .user(userName: "adamtofi", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/favourite",
            method: .POST,
            decodeTo: StatusDto.self
        )
        
        // Assert.
        XCTAssert(statusDto.id != nil, "Status wasn't created.")
        XCTAssertEqual(statusDto.favourited, true, "Status should be marked as favourited.")
        XCTAssertEqual(statusDto.favouritesCount, 1, "Favourited count should be equal 1.")
    }
    
    func testNotFoundShouldBeReturnedForStatusWithMentionedVisibility() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "brostofi")
        _ = try await User.create(userName: "ingatofi")
        let attachment = try await Attachment.create(user: user1)
        let status = try await Status.create(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "ingatofi", password: "p@ssword"),
            to: "/statuses/\(status.requireID())/favourite",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testNotFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        _ = try await User.create(userName: "maxtofi")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "maxtofi", password: "p@ssword"),
            to: "/statuses/123456789/favourite",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "moiquetofi")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/favourite",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
