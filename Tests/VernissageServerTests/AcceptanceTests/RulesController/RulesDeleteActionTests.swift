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

extension RulesControllerTests {
    
    @Suite("DELETE /:id", .serialized, .tags(.rules))
    struct RulesDeleteActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Rule should be deleted by authorized user")
        func ruleShouldBeDeletedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "larafoppo")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalRule = try await application.createRule(order: 41, text: "Rule 41")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "larafoppo", password: "p@ssword"),
                to: "/rules/" + (orginalRule.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let rule = try await application.getRule(text: "Rule 41")
            #expect(rule == nil, "Instance rule should be deleted.")
        }
        
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldBeReturneddForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogofoppo")
            let orginalRule = try await application.createRule(order: 42, text: "Rule 42")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "nogofoppo", password: "p@ssword"),
                to: "/rules/" + (orginalRule.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returned for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "yorigfoppo")
            let orginalRule = try await application.createRule(order: 43, text: "Rule 43")
            
            // Act.
            let response = try application.sendRequest(
                to: "/rules/" + (orginalRule.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
