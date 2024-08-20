//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class ReportsRestoreActionTests: CustomTestCase {
    func testReportShouldBeRestoredByAdministrator() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "robinvimin")
        try await user1.attach(role: Role.administrator)
        let user2 = try await User.create(userName: "martinvimin")
        
        let report = try await Report.create(
            userId: user1.requireID(),
            reportedUserId: user2.requireID(),
            statusId: nil,
            comment: "This is rude 1.",
            considerationDate: Date(),
            considerationUserId: user1.requireID()
        )
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "robinvimin", password: "p@ssword"),
            to: "/reports/\(report.stringId() ?? "")/restore",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let reportFromDatabase = try await Report.get(id: report.requireID())
        XCTAssertNil(reportFromDatabase?.$considerationUser.id, "Consideration user should be reset.");
        XCTAssertNil(reportFromDatabase?.considerationDate, "Consideration date should be reset.");
    }
    
    func testReportShouldBeRestoredByModerator() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "chrisvimin")
        try await user1.attach(role: Role.moderator)
        let user2 = try await User.create(userName: "evavimin")
        
        let report = try await Report.create(
            userId: user1.requireID(),
            reportedUserId: user2.requireID(),
            statusId: nil,
            comment: "This is rude 1.",
            considerationDate: Date(),
            considerationUserId: user1.requireID()
        )
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "chrisvimin", password: "p@ssword"),
            to: "/reports/\(report.stringId() ?? "")/restore",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let reportFromDatabase = try await Report.get(id: report.requireID())
        XCTAssertNil(reportFromDatabase?.$considerationUser.id, "Consideration user should be reset.");
        XCTAssertNil(reportFromDatabase?.considerationDate, "Consideration date should be reset.");
    }
    
    func testForbiddenShouldbeReturnedForRegularUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "trecvimin")
        let user2 = try await User.create(userName: "tnbqvimin")
        
        let report = try await Report.create(
            userId: user1.requireID(),
            reportedUserId: user2.requireID(),
            statusId: nil,
            comment: "This is rude 1.",
            considerationDate: Date(),
            considerationUserId: user1.requireID()
        )
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "trecvimin", password: "p@ssword"),
            to: "/reports/\(report.stringId() ?? "")/restore",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testUnauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "goblinvimin")
        let user2 = try await User.create(userName: "minvimin")
        let report = try await Report.create(
            userId: user1.requireID(),
            reportedUserId: user2.requireID(),
            statusId: nil,
            comment: "This is rude 1.",
            considerationDate: Date(),
            considerationUserId: user1.requireID()
        )
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/reports/\(report.stringId() ?? "")/restore",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
