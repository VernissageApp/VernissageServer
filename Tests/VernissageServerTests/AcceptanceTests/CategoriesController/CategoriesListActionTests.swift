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

@Suite("GET /", .serialized, .tags(.categories))
struct CategoriesListActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Categories list should be returned for authorized user")
    func categoriesListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        _ = try await application.createUser(userName: "wictortobim")

        // Act.
        let categories = try application.getResponse(
            as: .user(userName: "wictortobim", password: "p@ssword"),
            to: "/categories",
            method: .GET,
            decodeTo: [CategoryDto].self
        )

        // Assert.
        #expect(categories.count > 0, "Categories list should be returned.")
    }
    
    @Test("Categories list should be returned for only used parameter")
    func categoriesListShouldBeReturnedForOnlyUsedParameter() async throws {
        // Arrange.
        let user = try await application.createUser(userName: "rockytobim")
        let category = try await application.getCategory(name: "Abstract")!
        let (_, attachments) = try await application.createStatuses(user: user, notePrefix: "Note", categoryId: category.stringId(), amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }

        // Act.
        let categories = try application.getResponse(
            as: .user(userName: "rockytobim", password: "p@ssword"),
            to: "/categories?onlyUsed=true",
            method: .GET,
            decodeTo: [CategoryDto].self
        )

        // Assert.
        #expect(categories.count > 0, "Categories list should be returned.")
    }
    
    @Test("Categories list should not be returned for unauthorized user when categories are disabled")
    func categoriesListShouldNotBeReturnedForUnauthorizedUserWhenCategoriesAreDisabled() async throws {
        // Arrange.
        try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(false))
        
        // Act.
        let response = try application.sendRequest(
            to: "/categories",
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
        let response = try application.sendRequest(
            to: "/categories",
            method: .GET
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }
}

