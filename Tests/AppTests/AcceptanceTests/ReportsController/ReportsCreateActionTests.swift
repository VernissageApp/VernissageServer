//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class ReportsCreateActionTests: CustomTestCase {
    
    func testReportShouldBeCreatedByAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "lararomax")
        let user2 = try await User.create(userName: "romanromax")
        let reportDto = ReportRequestDto(reportedUserId: user2.stringId() ?? "", statusId: nil, comment: "Porn", forward: true, category: "Nude", ruleIds: [1, 2])
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "lararomax", password: "p@ssword"),
            to: "/reports",
            method: .POST,
            body: reportDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.created, "Response http status code should be created (201).")
        let report = try await Report.get(userId: user1.requireID())
        XCTAssertEqual(report?.user.id, user1.id, "User is should be set correctly.")
        XCTAssertEqual(report?.reportedUser.id, user2.id, "Reported is should be set correctly.")
        XCTAssertEqual(report?.comment, "Porn", "Comment is should be set correctly.")
        XCTAssertEqual(report?.forward, true, "Forward is should be set correctly.")
        XCTAssertEqual(report?.category, "Nude", "Forward is should be set correctly.")
        XCTAssertEqual(report?.ruleIds, "1,2", "Forward is should be set correctly.")
    }
    
    func testNotFoundShouldBeReturnedForNotExistingUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "eweromax")
        let reportDto = ReportRequestDto(reportedUserId: "1111", statusId: nil, comment: "Porn", forward: true, category: "Nude", ruleIds: [1, 2])
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "eweromax", password: "p@ssword"),
            to: "/reports",
            method: .POST,
            data: reportDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testNotFoundShouldBeReturnedForNotExistingStatus() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "trondromax")
        let user2 = try await User.create(userName: "tabiromax")
        let reportDto = ReportRequestDto(reportedUserId: user2.stringId() ?? "", statusId: 3431, comment: "Porn", forward: true, category: "Nude", ruleIds: [1, 2])
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "trondromax", password: "p@ssword"),
            to: "/reports",
            method: .POST,
            body: reportDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "chrisromax")
        let reportDto = ReportRequestDto(reportedUserId: user.stringId() ?? "", statusId: nil, comment: "Porn", forward: true, category: "Nude", ruleIds: [1, 2])
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/reports",
            method: .POST,
            body: reportDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
