//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class ReportsListActionTests: CustomTestCase {
    func testListOfReportsShouldBeReturnedForModeratorUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "robinrepix")
        try await user1.attach(role: Role.moderator)
        let user2 = try await User.create(userName: "martinrepix")

        _ = try await Report.create(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
        _ = try await Report.create(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 2.")
        
        // Act.
        let reports = try SharedApplication.application().getResponse(
            as: .user(userName: "robinrepix", password: "p@ssword"),
            to: "/reports",
            method: .GET,
            decodeTo: PaginableResultDto<ReportDto>.self
        )

        // Assert.
        XCTAssertNotNil(reports, "Reports should be returned.")
        XCTAssertTrue(reports.data.count > 0, "Some reports should be returned.")
    }
    
    func testListOfReportsShouldBeReturnedForAdministratorUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "wikirepix")
        try await user1.attach(role: Role.administrator)
        let user2 = try await User.create(userName: "gregrepix")

        _ = try await Report.create(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
        _ = try await Report.create(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 2.")
        
        // Act.
        let reports = try SharedApplication.application().getResponse(
            as: .user(userName: "wikirepix", password: "p@ssword"),
            to: "/reports",
            method: .GET,
            decodeTo: PaginableResultDto<ReportDto>.self
        )

        // Assert.
        XCTAssertNotNil(reports, "Reports should be returned.")
        XCTAssertTrue(reports.data.count > 0, "Some reports should be returned.")
    }
    
    func testForbiddenShouldbeReturnedForRegularUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "trelrepix")
        let user2 = try await User.create(userName: "mortenrepix")

        _ = try await Report.create(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
        _ = try await Report.create(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 2.")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "trelrepix", password: "p@ssword"),
            to: "/reports",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testListOfReportsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/reports", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
