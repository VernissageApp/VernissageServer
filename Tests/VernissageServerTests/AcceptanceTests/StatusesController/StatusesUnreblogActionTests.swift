//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class StatusesUnreblogActionTests: CustomTestCase {
    func testStatusShouldBeUnrebloggedForOrginalStatus() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "carinvox")
        let user2 = try await User.create(userName: "adamvox")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        _ = try await Status.reblog(user: user2, status: statuses.first!)
        
        // Act.
        let createdStatusDto = try SharedApplication.application().getResponse(
            as: .user(userName: "adamvox", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/unreblog",
            method: .POST,
            decodeTo: StatusDto.self
        )
        
        // Assert.
        XCTAssert(createdStatusDto.id != nil, "Status wasn't created.")
        XCTAssertEqual(createdStatusDto.reblogged, false, "Status should be marked as not reblogged.")
        XCTAssertEqual(createdStatusDto.reblogsCount, 0, "Reblogged count should be equal 0.")
        
        let notification = try await Notification.get(type: .reblog, to: user1.requireID(), by: user2.requireID(), statusId: createdStatusDto.id?.toId())
        XCTAssertNil(notification, "Notification should be deleted.")
    }
    
    func testStatusShouldBeUnrebloggedForReblogStatus() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "martinvox")
        let user2 = try await User.create(userName: "timvox")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        _ = try await Status.reblog(user: user2, status: statuses.first!)
        let reblog = try await Status.get(reblogId: statuses.first!.requireID())
        
        // Act.
        let createdStatusDto = try SharedApplication.application().getResponse(
            as: .user(userName: "timvox", password: "p@ssword"),
            to: "/statuses/\(reblog!.requireID())/unreblog",
            method: .POST,
            decodeTo: StatusDto.self
        )
        
        // Assert.
        XCTAssert(createdStatusDto.id != nil, "Status wasn't created.")
        XCTAssertEqual(createdStatusDto.reblogged, false, "Status should be marked as not reblogged.")
        XCTAssertEqual(createdStatusDto.reblogsCount, 0, "Reblogged count should be equal 0.")
    }
    
    func testStatusShouldReturnNotFoundForNotRebloggedStatus() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "romanvox")
        _ = try await User.create(userName: "georgevox")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
                
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "georgevox", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/unreblog",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "margotvox")
        let user2 = try await User.create(userName: "madamvox")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        _ = try await Status.reblog(user: user2, status: statuses.first!)
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/unreblog",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
