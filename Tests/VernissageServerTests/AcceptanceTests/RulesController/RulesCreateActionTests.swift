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

@Suite("POST /", .serialized, .tags(.rules))
struct RulesCreateActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Rule should be created by administrator")
    func ruleShouldBeCreatedByAdministrator() async throws {
        
        // Arrange.
        let user = try await application.createUser(userName: "larauviok")
        try await application.attach(user: user, role: Role.moderator)

        let ruleDto = RuleDto(order: 10, text: "Rule 10")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "larauviok", password: "p@ssword"),
            to: "/rules",
            method: .POST,
            body: ruleDto
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
        let rule = try await application.getRule(text: "Rule 10")
        #expect(rule?.order == 10, "Order should be set correctly.")
    }
    
    @Test("Rule should not be created if text was not specified")
    func ruleShouldNotBeCreatedIfTextWasNotSpecified() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "nikouviok")
        try await application.attach(user: user, role: Role.moderator)

        let ruleDto = RuleDto(order: 11, text: "")

        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "nikouviok", password: "p@ssword"),
            to: "/rules",
            method: .POST,
            data: ruleDto
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("text") == "is empty")
    }

    @Test("Rule should not be created if text is too long")
    func ruleShouldNotBeCreatedIfTextIsTooLong() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "robotuviok")
        try await application.attach(user: user, role: Role.moderator)

        let ruleDto = RuleDto(order: 12, text: String.createRandomString(length: 1001))

        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "robotuviok", password: "p@ssword"),
            to: "/rules",
            method: .POST,
            data: ruleDto
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("text") == "is greater than maximum of 1000 character(s)")
    }
    
    @Test("Forbidden should be returnedd for regular user")
    func forbiddenShouldBeReturneddForRegularUser() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "nogouviok")
        let ruleDto = RuleDto(order: 13, text: "Rule 13")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "nogouviok", password: "p@ssword"),
            to: "/rules",
            method: .POST,
            body: ruleDto
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
    }
    
    @Test("Unauthorize should be returnedd for not authorized user")
    func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "yoriuviok")
        let ruleDto = RuleDto(order: 14, text: "Rule 14")
        
        // Act.
        let response = try application.sendRequest(
            to: "/rules",
            method: .POST,
            body: ruleDto
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
