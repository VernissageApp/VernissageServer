//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class RulesUpdateActionTests: CustomTestCase {
    func testRuleShouldBeUpdatedByAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "laraquibo")
        try await user.attach(role: Role.moderator)

        let orginalRule = try await Rule.create(order: 21, text: "Rule 21")
        let ruleDto = RuleDto(order: 31, text: "Rule 31")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "laraquibo", password: "p@ssword"),
            to: "/rules/" + (orginalRule.stringId() ?? ""),
            method: .PUT,
            body: ruleDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be created (200).")
        let rule = try await Rule.get(text: "Rule 31")
        XCTAssertEqual(rule?.order, 31, "Order should be set correctly.")
    }
    
    func testRuleShouldNotBeUpdatedIfTextWasNotSpecified() async throws {

        // Arrange.
        let user = try await User.create(userName: "nikouquibo")
        try await user.attach(role: Role.moderator)

        let orginalRule = try await Rule.create(order: 22, text: "Rule 22")
        let ruleDto = RuleDto(order: 32, text: "")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "nikouquibo", password: "p@ssword"),
            to: "/rules/" + (orginalRule.stringId() ?? ""),
            method: .PUT,
            data: ruleDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("text"), "is empty")
    }

    func testRuleShouldNotBeUpdatedIfTextIsTooLong() async throws {

        // Arrange.
        let user = try await User.create(userName: "henryquibo")
        try await user.attach(role: Role.moderator)

        let orginalRule = try await Rule.create(order: 23, text: "Rule 23")
        let ruleDto = RuleDto(order: 33, text: String.createRandomString(length: 1001))

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "henryquibo", password: "p@ssword"),
            to: "/rules/" + (orginalRule.stringId() ?? ""),
            method: .PUT,
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
        _ = try await User.create(userName: "nogoquibo")
        
        let orginalRule = try await Rule.create(order: 25, text: "Rule 25")
        let ruleDto = RuleDto(order: 35, text: "Rule 35")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nogoquibo", password: "p@ssword"),
            to: "/rules/" + (orginalRule.stringId() ?? ""),
            method: .PUT,
            body: ruleDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
    }
    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "yoriquibo")

        let orginalRule = try await Rule.create(order: 26, text: "Rule 26")
        let ruleDto = RuleDto(order: 36, text: "Rule 36")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/rules/" + (orginalRule.stringId() ?? ""),
            method: .PUT,
            body: ruleDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
