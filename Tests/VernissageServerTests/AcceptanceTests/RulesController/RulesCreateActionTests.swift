//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class RulesCreateActionTests: CustomTestCase {
    func testRuleShouldBeCreatedByAdministrator() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "larauviok")
        try await user.attach(role: Role.moderator)

        let ruleDto = RuleDto(order: 10, text: "Rule 10")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "larauviok", password: "p@ssword"),
            to: "/rules",
            method: .POST,
            body: ruleDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.created, "Response http status code should be created (201).")
        let rule = try await Rule.get(text: "Rule 10")
        XCTAssertEqual(rule?.order, 10, "Order should be set correctly.")
    }
    
    func testRuleShouldNotBeCreatedIfTextWasNotSpecified() async throws {

        // Arrange.
        let user = try await User.create(userName: "nikouviok")
        try await user.attach(role: Role.moderator)

        let ruleDto = RuleDto(order: 11, text: "")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "nikouviok", password: "p@ssword"),
            to: "/rules",
            method: .POST,
            data: ruleDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("text"), "is empty")
    }

    func testRuleShouldNotBeCreatedIfTextIsTooLong() async throws {

        // Arrange.
        let user = try await User.create(userName: "robotuviok")
        try await user.attach(role: Role.moderator)

        let ruleDto = RuleDto(order: 12, text: String.createRandomString(length: 1001))

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "robotuviok", password: "p@ssword"),
            to: "/rules",
            method: .POST,
            data: ruleDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("text"), "is greater than maximum of 1000 character(s)")
    }
    

    func testForbiddenShouldBeReturneddForRegularUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "nogouviok")
        let ruleDto = RuleDto(order: 13, text: "Rule 13")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nogouviok", password: "p@ssword"),
            to: "/rules",
            method: .POST,
            body: ruleDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
    }
    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "yoriuviok")
        let ruleDto = RuleDto(order: 14, text: "Rule 14")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/rules",
            method: .POST,
            body: ruleDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
