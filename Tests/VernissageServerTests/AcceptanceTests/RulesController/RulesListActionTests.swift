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
    
    @Suite("Rules (GET /rules)", .serialized, .tags(.rules))
    struct RulesListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of rules should be returned for moderator user")
        func listOfRulesShouldBeReturnedForModeratorUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinfukx")
            try await application.attach(user: user, role: Role.moderator)
            
            _ = try await application.createRule(order: 1, text: "Rule 1")
            _ = try await application.createRule(order: 2, text: "Rule 2")
            
            // Act.
            let rules = try await application.getResponse(
                as: .user(userName: "robinfukx", password: "p@ssword"),
                to: "/rules",
                method: .GET,
                decodeTo: PaginableResultDto<RuleDto>.self
            )
            
            // Assert.
            #expect(rules != nil, "Instance rules should be returned.")
            #expect(rules.data.count > 0, "Some rules should be returned.")
        }
        
        @Test("List of rules should be returned for administrator user")
        func listOfRulesShouldBeReturnedForAdministratorUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "wikifukx")
            try await application.attach(user: user1, role: Role.administrator)
            
            _ = try await application.createRule(order: 3, text: "Rule 3")
            _ = try await application.createRule(order: 4, text: "Rule 4")
            
            // Act.
            let rules = try await application.getResponse(
                as: .user(userName: "wikifukx", password: "p@ssword"),
                to: "/rules",
                method: .GET,
                decodeTo: PaginableResultDto<RuleDto>.self
            )
            
            // Assert.
            #expect(rules != nil, "Instance rules should be returned.")
            #expect(rules.data.count > 0, "Some rules should be returned.")
        }
        
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldbeReturnedForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "trelfukx")
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "trelfukx", password: "p@ssword"),
                to: "/rules",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("List of rules should not be returned when user is not authorized")
        func istOfRulesShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/rules", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
