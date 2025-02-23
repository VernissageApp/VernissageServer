//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Categories (POST /categories/:id/disable)", .serialized, .tags(.categories))
    struct CategoriesDisableActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Category isEnabled flag should be updated by authorized user")
        func categoryShouldBeUpdatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laramexico")
            try await application.attach(user: user, role: Role.moderator)
            
            let category = try await application.getCategory(name: "Macro")
            try await application.setCategoryEnabled(name: "Macro", enabled: true)
                        
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "laramexico", password: "p@ssword"),
                to: "/categories/" + (category?.stringId() ?? "") + "/disable",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let categoryAfterUpdate = try await application.getCategory(name: "Macro")
            #expect(categoryAfterUpdate?.isEnabled == false, "Enabled flag should be set correctly.")
        }
                        
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldBeReturneddForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogomexico")
            let category = try await application.getCategory(name: "Macro")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "nogomexico", password: "p@ssword"),
                to: "/categories/" + (category?.stringId() ?? "") + "/disable",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let category = try await application.getCategory(name: "Macro")
            
            // Act.
            let response = try application.sendRequest(
                to: "/categories/" + (category?.stringId() ?? "") + "/disable",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
