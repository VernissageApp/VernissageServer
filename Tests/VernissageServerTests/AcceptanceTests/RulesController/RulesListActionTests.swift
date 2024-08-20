//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class RulesListActionTests: CustomTestCase {
    func testListOfRulesShouldBeReturnedForModeratorUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robinfukx")
        try await user.attach(role: Role.moderator)
        
        _ = try await Rule.create(order: 1, text: "Rule 1")
        _ = try await Rule.create(order: 2, text: "Rule 2")
        
        // Act.
        let rules = try SharedApplication.application().getResponse(
            as: .user(userName: "robinfukx", password: "p@ssword"),
            to: "/rules",
            method: .GET,
            decodeTo: PaginableResultDto<RuleDto>.self
        )

        // Assert.
        XCTAssertNotNil(rules, "Instance rules should be returned.")
        XCTAssertTrue(rules.data.count > 0, "Some rules should be returned.")
    }
    
    func testListOfRulesShouldBeReturnedForAdministratorUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "wikifukx")
        try await user1.attach(role: Role.administrator)
        
        _ = try await Rule.create(order: 3, text: "Rule 3")
        _ = try await Rule.create(order: 4, text: "Rule 4")
        
        // Act.
        let rules = try SharedApplication.application().getResponse(
            as: .user(userName: "wikifukx", password: "p@ssword"),
            to: "/rules",
            method: .GET,
            decodeTo: PaginableResultDto<RuleDto>.self
        )

        // Assert.
        XCTAssertNotNil(rules, "Instance rules should be returned.")
        XCTAssertTrue(rules.data.count > 0, "Some rules should be returned.")
    }
    
    func testForbiddenShouldbeReturnedForRegularUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "trelfukx")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "trelfukx", password: "p@ssword"),
            to: "/rules",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testListOfRulesShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/rules", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
