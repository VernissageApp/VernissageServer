//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class RulesDeleteActionTests: CustomTestCase {
    func testRuleShouldBeDeletedByAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "larafoppo")
        try await user.attach(role: Role.moderator)

        let orginalRule = try await Rule.create(order: 41, text: "Rule 41")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "larafoppo", password: "p@ssword"),
            to: "/rules/" + (orginalRule.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be created (200).")
        let rule = try await Rule.get(text: "Rule 41")
        XCTAssertNil(rule, "Instance rule should be deleted.")
    }
    
    func testForbiddenShouldBeReturneddForRegularUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "nogofoppo")
        let orginalRule = try await Rule.create(order: 42, text: "Rule 42")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nogofoppo", password: "p@ssword"),
            to: "/rules/" + (orginalRule.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
    }
    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "yorigfoppo")
        let orginalRule = try await Rule.create(order: 43, text: "Rule 43")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/rules/" + (orginalRule.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
