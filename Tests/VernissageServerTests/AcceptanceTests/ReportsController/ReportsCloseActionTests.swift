//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class ReportsCloseActionTests: CustomTestCase {
    func testReportShouldBeClosedByAdministrator() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "robinroxit")
        try await user1.attach(role: Role.administrator)
        let user2 = try await User.create(userName: "martinroxit")
        
        let report = try await Report.create(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "robinroxit", password: "p@ssword"),
            to: "/reports/\(report.stringId() ?? "")/close",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let reportFromDatabase = try await Report.get(id: report.requireID())
        XCTAssertNotNil(reportFromDatabase?.$considerationUser.id, "Consideration user should be saved.");
        XCTAssertNotNil(reportFromDatabase?.considerationDate, "Consideration date should be saved.");
    }
    
    func testReportShouldBeClosedByModerator() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "chrisroxit")
        try await user1.attach(role: Role.moderator)
        let user2 = try await User.create(userName: "evaroxit")
        
        let report = try await Report.create(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "chrisroxit", password: "p@ssword"),
            to: "/reports/\(report.stringId() ?? "")/close",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let reportFromDatabase = try await Report.get(id: report.requireID())
        XCTAssertNotNil(reportFromDatabase?.$considerationUser.id, "Consideration user should be saved.");
        XCTAssertNotNil(reportFromDatabase?.considerationDate, "Consideration date should be saved.");
    }
    
    func testForbiddenShouldbeReturnedForRegularUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "trecroxit")
        let user2 = try await User.create(userName: "tnbqroxit")
        
        let report = try await Report.create(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "trecroxit", password: "p@ssword"),
            to: "/reports/\(report.stringId() ?? "")/close",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testUnauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "goblinroxit")
        let user2 = try await User.create(userName: "minroxit")
        let report = try await Report.create(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/reports/\(report.stringId() ?? "")/close",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
