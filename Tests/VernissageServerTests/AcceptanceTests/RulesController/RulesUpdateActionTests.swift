//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Rules (PUT /rules/:id)", .serialized, .tags(.rules))
    struct RulesUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Rule should be updated by authorized user")
        func ruleShouldBeUpdatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laraquibo")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalRule = try await application.createRule(order: 21, text: "Rule 21")
            let ruleDto = RuleDto(order: 31, text: "Rule 31")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "laraquibo", password: "p@ssword"),
                to: "/rules/" + (orginalRule.stringId() ?? ""),
                method: .PUT,
                body: ruleDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let rule = try await application.getRule(text: "Rule 31")
            #expect(rule?.order == 31, "Order should be set correctly.")
        }
        
        @Test("Rule should not be updated if text was not specified")
        func ruleShouldNotBeUpdatedIfTextWasNotSpecified() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikouquibo")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalRule = try await application.createRule(order: 22, text: "Rule 22")
            let ruleDto = RuleDto(order: 32, text: "")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "nikouquibo", password: "p@ssword"),
                to: "/rules/" + (orginalRule.stringId() ?? ""),
                method: .PUT,
                data: ruleDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("text") == "is empty")
        }
        
        @Test("Rule should not be updated if text is too long")
        func ruleShouldNotBeUpdatedIfTextIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "henryquibo")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalRule = try await application.createRule(order: 23, text: "Rule 23")
            let ruleDto = RuleDto(order: 33, text: String.createRandomString(length: 1001))
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "henryquibo", password: "p@ssword"),
                to: "/rules/" + (orginalRule.stringId() ?? ""),
                method: .PUT,
                data: ruleDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("text") == "is greater than maximum of 1000 character(s)")
        }
        
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldBeReturneddForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogoquibo")
            
            let orginalRule = try await application.createRule(order: 25, text: "Rule 25")
            let ruleDto = RuleDto(order: 35, text: "Rule 35")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "nogoquibo", password: "p@ssword"),
                to: "/rules/" + (orginalRule.stringId() ?? ""),
                method: .PUT,
                body: ruleDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returned for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "yoriquibo")
            
            let orginalRule = try await application.createRule(order: 26, text: "Rule 26")
            let ruleDto = RuleDto(order: 36, text: "Rule 36")
            
            // Act.
            let response = try application.sendRequest(
                to: "/rules/" + (orginalRule.stringId() ?? ""),
                method: .PUT,
                body: ruleDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
