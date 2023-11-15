//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class StatusesDeleteActionTests: CustomTestCase {
    
    func testStatusShouldBeDeletedForAuthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robinworth")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
                
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "robinworth", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let statusFromDatabase = try? await Status.get(id: statuses.first!.requireID())
        XCTAssert(statusFromDatabase == nil, "Status should be deleted.")
    }
    
    func testStatusAndHisReblogsShouldBeDeletedForAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "carinworth")
        let user2 = try await User.create(userName: "adamworth")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        let reblog = try await Status.reblog(user: user2, status: statuses.first!)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "carinworth", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let statusFromDatabase = try? await Status.get(id: statuses.first!.requireID())
        XCTAssert(statusFromDatabase == nil, "Orginal status should be deleted.")
        
        let reblogStatusFromDatabase = try? await Status.get(id: reblog.requireID())
        XCTAssert(reblogStatusFromDatabase == nil, "Reblog status should be deleted.")
    }
    
    func testStatusAndHisRepliesShouldBeDeletedForAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "maxworth")
        let user2 = try await User.create(userName: "benworth")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        let status2A = try await Status.reply(user: user2, comment: "This is reply for status 1", status: statuses.first!)
        let status2B = try await Status.reply(user: user2, comment: "This is reply for status 1", status: statuses.first!)
        let status3A = try await Status.reply(user: user2, comment: "This is reply for status 2A", status: status2A)
        let status3B = try await Status.reply(user: user2, comment: "This is reply for status 2B", status: status2B)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "maxworth", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let statusFromDatabase = try? await Status.get(id: statuses.first!.requireID())
        XCTAssert(statusFromDatabase == nil, "Orginal status should be deleted.")
        
        let status2AFromDatabase = try? await Status.get(id: status2A.requireID())
        XCTAssert(status2AFromDatabase == nil, "Reply status2A status should be deleted.")
        
        let status2BFromDatabase = try? await Status.get(id: status2B.requireID())
        XCTAssert(status2BFromDatabase == nil, "Reply status2B status should be deleted.")
        
        let status3AFromDatabase = try? await Status.get(id: status3A.requireID())
        XCTAssert(status3AFromDatabase == nil, "Reply status3A status should be deleted.")
        
        let status3BFromDatabase = try? await Status.get(id: status3B.requireID())
        XCTAssert(status3BFromDatabase == nil, "Reply status3B status should be deleted.")
    }
    
    func testStatusAndHisHashtagsShouldBeDeletedForAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "richardworth")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note #photo #blackandwhite", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "richardworth", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let statusFromDatabase = try? await Status.get(id: statuses.first!.requireID())
        XCTAssert(statusFromDatabase == nil, "Orginal status should be deleted.")
    }
    
    func testStatusAndHisMentionsShouldBeDeletedForAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "marecworth")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note @marcin @kamila", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "marecworth", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let statusFromDatabase = try? await Status.get(id: statuses.first!.requireID())
        XCTAssert(statusFromDatabase == nil, "Orginal status should be deleted.")
    }
    
    func testStatusShouldNotBeDeletedForUnauthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "erikworth")
        let attachment1 = try await Attachment.create(user: user)
        defer {
            Status.clearFiles(attachments: [attachment1])
        }
        
        let status = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/statuses/\(status.requireID())",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testStatusShouldNotBeDeletedForStatusCreatedByOtherUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "maciasworth")
        let user = try await User.create(userName: "georgeworth")
        let attachment1 = try await Attachment.create(user: user)
        defer {
            Status.clearFiles(attachments: [attachment1])
        }
        
        let status = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "maciasworth", password: "p@ssword"),
            to: "/statuses/\(status.requireID())",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
}
