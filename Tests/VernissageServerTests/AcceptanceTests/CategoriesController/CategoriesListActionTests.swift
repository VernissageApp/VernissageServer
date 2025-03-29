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
    
    @Suite("Categories (GET /categories)", .serialized, .tags(.categories))
    struct CategoriesListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of categories should be returned for moderator user")
        func listOfCategoriesShouldBeReturnedForModeratorUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorpopis")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let categories = try await application.getResponse(
                as: .user(userName: "wictorpopis", password: "p@ssword"),
                to: "/categories",
                method: .GET,
                decodeTo: PaginableResultDto<CategoryDto>.self
            )
            
            // Assert.
            #expect(categories.data.count > 0, "Categories list should be returned.")
            #expect((categories.data.first?.hashtags?.count ?? 0) > 0, "Category hashtags list should be returned.")
        }
        
        @Test("List of categories should be returned for administrator user")
        func listOfCategoriesShouldBeReturnedForAdministratorUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "romanpopis")
            try await application.attach(user: user, role: Role.administrator)
            
            // Act.
            let categories = try await application.getResponse(
                as: .user(userName: "romanpopis", password: "p@ssword"),
                to: "/categories",
                method: .GET,
                decodeTo: PaginableResultDto<CategoryDto>.self
            )
            
            // Assert.
            #expect(categories.data.count > 0, "Categories list should be returned.")
            #expect((categories.data.first?.hashtags?.count ?? 0) > 0, "Category hashtags list should be returned.")
        }
                
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldbeReturnedForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "annapopis")
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "annapopis", password: "p@ssword"),
                to: "/categories",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Unauthorized should be returned for regular user")
        func unauthorizedShouldbeReturnedForRegularUser() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/categories", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
