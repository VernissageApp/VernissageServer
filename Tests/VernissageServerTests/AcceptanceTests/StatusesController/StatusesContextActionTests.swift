//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class StatusesContextActionTests: CustomTestCase {
    
    func testStatusContextShouldBeReturnedForUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "robintopiq")
        
        let attachment1 = try await Attachment.create(user: user)
        let attachment2 = try await Attachment.create(user: user)
        let attachment3 = try await Attachment.create(user: user)
        let attachment4 = try await Attachment.create(user: user)
        let attachment5 = try await Attachment.create(user: user)
        
        let status1 = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
        let status2 = try await Status.create(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], replyToStatusId: status1.stringId())
        let status3 = try await Status.create(user: user, note: "Note 3", attachmentIds: [attachment3.stringId()!], replyToStatusId: status2.stringId())
        let status4 = try await Status.create(user: user, note: "Note 4", attachmentIds: [attachment4.stringId()!], replyToStatusId: status3.stringId())
        let status5 = try await Status.create(user: user, note: "Note 5", attachmentIds: [attachment5.stringId()!], replyToStatusId: status3.stringId())
        
        defer {
            Status.clearFiles(attachments: [attachment1, attachment2, attachment3, attachment4, attachment5])
        }
        
        // Act.
        let statusContextDto = try SharedApplication.application().getResponse(
            as: .user(userName: "robintopiq", password: "p@ssword"),
            to: "/statuses/\(status3.requireID())/context",
            method: .GET,
            decodeTo: StatusContextDto.self
        )
        
        // Assert.
        XCTAssertNotNil(statusContextDto, "Status context should be returned.")
        XCTAssertEqual(status1.stringId(), statusContextDto.ancestors[0].id, "First status ancestor should be returned.")
        XCTAssertEqual(status2.stringId(), statusContextDto.ancestors[1].id, "Second status ancestor should be returned.")
        XCTAssertEqual(status4.stringId(), statusContextDto.descendants[0].id, "First status descendant should be returned.")
        XCTAssertEqual(status5.stringId(), statusContextDto.descendants[1].id, "Second status descendant should be returned.")
    }
    
    func testNotFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        _ = try await User.create(userName: "maxtopiq")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "maxtopiq", password: "p@ssword"),
            to: "/statuses/123456789/context",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
