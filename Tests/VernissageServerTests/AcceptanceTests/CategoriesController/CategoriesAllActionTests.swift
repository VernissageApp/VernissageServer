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
    
    @Suite("Categories (GET /categories/all)", .serialized, .tags(.categories))
    struct CategoriesAllActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("All categories should be returned for authorized user")
        func allCategoriesShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "wictortobim")
            
            // Act.
            let categories = try await application.getResponse(
                as: .user(userName: "wictortobim", password: "p@ssword"),
                to: "/categories/all",
                method: .GET,
                decodeTo: [CategoryDto].self
            )
            
            // Assert.
            #expect(categories.count > 0, "Categories list should be returned.")
            #expect((categories.first?.hashtags?.count ?? 0) > 0, "Category hashtags list should be returned.")
        }
        
        @Test("All categories should be returned for only used parameter")
        func allCategoriesShouldBeReturnedForOnlyUsedParameter() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "rockytobim")
            let category = try await application.getCategory(name: "Abstract")!
            let (_, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Only Used", categoryId: category.stringId(), amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let categories = try await application.getResponse(
                as: .user(userName: "rockytobim", password: "p@ssword"),
                to: "/categories/all?onlyUsed=true",
                method: .GET,
                decodeTo: [CategoryDto].self
            )
            
            // Assert.
            #expect(categories.count > 0, "Categories list should be returned.")
        }
        
        @Test("Disabled category should not be returned")
        func disabledCategoryShouldNotBeReturned() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "wtobistobim")
            try await application.setCategoryEnabled(name: "Journalism", enabled: false)
            
            // Act.
            let categories = try await application.getResponse(
                as: .user(userName: "wtobistobim", password: "p@ssword"),
                to: "/categories/all",
                method: .GET,
                decodeTo: [CategoryDto].self
            )
            
            // Assert.
            #expect(categories.count > 0, "Categories list should be returned.")
            #expect(categories.contains {$0.name == "Journalism" } == false, "Disabled category should not be returned.")
        }
        
        @Test("Categories list should not be returned for unauthorized user when categories are disabled")
        func categoriesListShouldNotBeReturnedForUnauthorizedUserWhenCategoriesAreDisabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try await application.sendRequest(
                to: "/categories/all",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Categories list should be returned for unauthorized user when categories are enabled")
        func categoriesListShouldBeReturnedForUnauthorizedUserWhenCategoriesAreEnabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(true))
            
            // Act.
            let response = try await application.sendRequest(
                to: "/categories/all",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        }
    }
}
