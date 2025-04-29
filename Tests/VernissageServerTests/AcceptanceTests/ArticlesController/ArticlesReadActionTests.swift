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
    
    @Suite("Articles (GET /articles/:id)", .serialized, .tags(.articles))
    struct ArticlesReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Article should be returned for moderator user even when news are disabled")
        func articleShouldBeReturnedForModeratorUserEvenWhenNewsAreDisabled() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictortronch")
            try await application.attach(user: user, role: Role.moderator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await application.updateSetting(key: .showNews, value: .boolean(false))
            try await application.updateSetting(key: .showNewsForAnonymous, value: .boolean(false))
            
            // Act.
            let result = try await application.getResponse(
                as: .user(userName: "wictortronch", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? ""),
                method: .GET,
                decodeTo: ArticleDto.self
            )
            
            // Assert.
            #expect(result.id != nil, "Article should be returned.")
            #expect(result.title == "Title", "Article title should be returned.")
            #expect(result.body == "Article body", "Article body should be returned.")
        }
        
        @Test("Article should be returned for administrator user even when news are disabled")
        func articleShouldBeReturnedForAdministratorUserEvenWhenNewsAreDisabled() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "adamtronch")
            try await application.attach(user: user, role: Role.administrator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signOutNews)
            try await application.updateSetting(key: .showNews, value: .boolean(false))
            try await application.updateSetting(key: .showNewsForAnonymous, value: .boolean(false))
            
            // Act.
            let result = try await application.getResponse(
                as: .user(userName: "adamtronch", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? ""),
                method: .GET,
                decodeTo: ArticleDto.self
            )
            
            // Assert.
            #expect(result.id != nil, "Article should be returned.")
            #expect(result.title == "Title", "Article title should be returned.")
            #expect(result.body == "Article body", "Article body should be returned.")
        }
        
        @Test("Article should be returned for regular user when news are enabled")
        func articleShouldBeReturnedForRegularUserWhenNewsAreEnabled() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "karolinatronch")

            let user = try await application.createUser(userName: "tobiasztronch")
            try await application.attach(user: user, role: Role.administrator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await application.updateSetting(key: .showNews, value: .boolean(true))
            
            // Act.
            let result = try await application.getResponse(
                as: .user(userName: "karolinatronch", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? ""),
                method: .GET,
                decodeTo: ArticleDto.self
            )
            
            // Assert.
            #expect(result.id != nil, "Article should be returned.")
            #expect(result.title == "Title", "Article title should be returned.")
            #expect(result.body == "Article body", "Article body should be returned.")
        }
        
        @Test("Article should not be returned for regular user when news are disabled")
        func articleShouldNotBeReturnedForRegularUserWhenNewsAreDisabled() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "roberttronch")

            let user = try await application.createUser(userName: "wiktortronch")
            try await application.attach(user: user, role: Role.administrator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await application.updateSetting(key: .showNews, value: .boolean(false))
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "roberttronch", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? ""),
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthorized (403).")
        }
        
        @Test("Article should be returned for not authorized user and signed out news visibility when news are enabled")
        func articleShouldBeReturnedForNotAuthorizedUserAndSignedOutNewsVisibilityWhenNewsAreEnabled() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "bobektronch")
            try await application.attach(user: user, role: Role.administrator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signOutNews)
            try await application.updateSetting(key: .showNewsForAnonymous, value: .boolean(true))
            
            // Act.
            let result = try await application.getResponse(
                to: "/articles/" + (article.stringId() ?? ""),
                method: .GET,
                decodeTo: ArticleDto.self
            )
            
            // Assert.
            #expect(result.id != nil, "Article should be returned.")
            #expect(result.title == "Title", "Article title should be returned.")
            #expect(result.body == "Article body", "Article body should be returned.")
        }
        
        @Test("Article should be returned for not authorized user and signed out news visibility with disabled public news")
        func articleShouldBeReturnedForNotAuthorizedUserAndSignedOutNewsVisibilityWithDisabledPublic() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "hannatronch")
            try await application.attach(user: user, role: Role.administrator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signOutNews)
            try await application.updateSetting(key: .showNewsForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/articles/" + (article.stringId() ?? ""),
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Unauthorized should be returned for not authorized user and signed in news visibility")
        func unauthorizedShouldBeReturendForNotAuthorizedUserAndSignedInNewsVisibility() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "martintronch")
            try await application.attach(user: user, role: Role.administrator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await application.updateSetting(key: .showNewsForAnonymous, value: .boolean(true))
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/articles/" + (article.stringId() ?? ""),
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Unauthorized should be returned for not authorized user and signed in home visibility")
        func unauthorizedShouldBeReturendForNotAuthorizedUserAndSignedInHomeVisibility() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "mondektronch")
            try await application.attach(user: user, role: Role.administrator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInHome)
            try await application.updateSetting(key: .showNewsForAnonymous, value: .boolean(true))
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/articles/" + (article.stringId() ?? ""),
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
