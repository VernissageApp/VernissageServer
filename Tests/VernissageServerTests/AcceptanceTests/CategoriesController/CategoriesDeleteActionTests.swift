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
    
    @Suite("Categories (DELETE /categories/:id)", .serialized, .tags(.categories))
    struct CategoriesDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Category should be deleted by authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "lararoboto")
            try await application.attach(user: user, role: Role.moderator)
            
            let category = try await application.getCategory(name: "Night")
                        
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "lararoboto", password: "p@ssword"),
                to: "/categories/" + (category?.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let categoryAfterDelete = try await application.getCategory(name: "Night")
            #expect(categoryAfterDelete == nil, "Category should be deleted.")
        }
                
        @Test
        func `Forbidden should be returned for regular user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogoroboto")
            let category = try await application.getCategory(name: "Wedding")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogoroboto", password: "p@ssword"),
                to: "/categories/" + (category?.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test
        func `Unauthorize should be returnedd for not authorized user`() async throws {
            
            // Arrange.
            let category = try await application.getCategory(name: "Wedding")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/categories/" + (category?.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
