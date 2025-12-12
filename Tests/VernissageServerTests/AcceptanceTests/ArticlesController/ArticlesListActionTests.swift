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
    
    @Suite("Articles (GET /articles)", .serialized, .tags(.articles))
    struct ArticlesListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `List of all articles should be returned for moderator user even when news are disabled`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictortemulop")
            try await application.attach(user: user, role: Role.moderator)
            _ = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await application.updateSetting(key: .showNews, value: .boolean(false))
            try await application.updateSetting(key: .showNewsForAnonymous, value: .boolean(false))
            
            // Act.
            let articles = try await application.getResponse(
                as: .user(userName: "wictortemulop", password: "p@ssword"),
                to: "/articles",
                method: .GET,
                decodeTo: PaginableResultDto<ArticleDto>.self
            )
            
            // Assert.
            #expect(articles.data.count > 0, "Articles list should be returned.")
        }
        
        @Test
        func `List of articles should be returned for administrator user even when news are disabled`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "adamtemulop")
            try await application.attach(user: user, role: Role.administrator)
            _ = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await application.updateSetting(key: .showNews, value: .boolean(false))
            try await application.updateSetting(key: .showNewsForAnonymous, value: .boolean(false))
            
            // Act.
            let articles = try await application.getResponse(
                as: .user(userName: "adamtemulop", password: "p@ssword"),
                to: "/articles",
                method: .GET,
                decodeTo: PaginableResultDto<ArticleDto>.self
            )
            
            // Assert.
            #expect(articles.data.count > 0, "Articles list should be returned.")
        }
        
        @Test
        func `List of articles should be returned for regular user without dismissed when news are enabled`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "gorrrtemulop")
            _ = try await application.createArticle(userId: user.requireID(), title: "Title #1", body: "Article body", visibility: .signInNews)
            let article = try await application.createArticle(userId: user.requireID(), title: "Dismissed title #1", body: "Article body", visibility: .signInNews)
            _ = try await application.createArticleRead(userId: user.requireID(), articleId: article.requireID())
            try await application.updateSetting(key: .showNews, value: .boolean(true))
            
            // Act.
            let articles = try await application.getResponse(
                as: .user(userName: "gorrrtemulop", password: "p@ssword"),
                to: "/articles?visibility=signInNews",
                method: .GET,
                decodeTo: PaginableResultDto<ArticleDto>.self
            )
            
            // Assert.
            #expect(articles.data.contains(where: { $0.title == "Dismissed title #1" }) == false, "Dismissed article should not be returned.")
        }
                
        @Test
        func `List of articles should be returned for regular user with dismissed when dismissed flag is specified`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "dianatemulop")
            _ = try await application.createArticle(userId: user.requireID(), title: "Visible title #1", body: "Article body", visibility: .signInNews)
            let article = try await application.createArticle(userId: user.requireID(), title: "Visible title #2 (dismissed)", body: "Article body", visibility: .signInNews)
            _ = try await application.createArticleRead(userId: user.requireID(), articleId: article.requireID())
            try await application.updateSetting(key: .showNews, value: .boolean(true))
            
            // Act.
            let articles = try await application.getResponse(
                as: .user(userName: "dianatemulop", password: "p@ssword"),
                to: "/articles?visibility=signInNews&dismissed=true",
                method: .GET,
                decodeTo: PaginableResultDto<ArticleDto>.self
            )
            
            // Assert.
            #expect(articles.data.contains(where: { $0.title == "Visible title #1" }), "Not dismissed article should be visible.")
            #expect(articles.data.contains(where: { $0.title == "Visible title #2 (dismissed)" }), "Dismissed article should be visible.")
        }
        
        @Test
        func `Signed in news articles should not be returned for regular user when news are disabled`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "anquatemulop")
            _ = try await application.createArticle(userId: user.requireID(), title: "Disabled  anquatemulop", body: "Article body", visibility: .signInNews)
            try await application.updateSetting(key: .showNews, value: .boolean(false))
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "anquatemulop", password: "p@ssword"),
                to: "/articles?visibility=signInNews",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }

        @Test
        func `List of articles should be returned for not authorized user and signed out home visibility`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "borisemulop")
            try await application.attach(user: user, role: Role.administrator)
            _ = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signOutHome)
            try await application.updateSetting(key: .showNewsForAnonymous, value: .boolean(true))
            
            // Act.
            let articles = try await application.getResponse(
                to: "/articles?visibility=signOutHome",
                method: .GET,
                decodeTo: PaginableResultDto<ArticleDto>.self
            )
            
            // Assert.
            #expect(articles.data.count > 0, "Articles list should be returned.")
        }
        
        @Test
        func `List of articles should be returned for not authorized user and signed out news visibility and signed out news are enabled`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "frankemulop")
            try await application.attach(user: user, role: Role.administrator)
            _ = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signOutNews)
            try await application.updateSetting(key: .showNewsForAnonymous, value: .boolean(true))
            
            // Act.
            let articles = try await application.getResponse(
                to: "/articles?visibility=signOutNews",
                method: .GET,
                decodeTo: PaginableResultDto<ArticleDto>.self
            )
            
            // Assert.
            #expect(articles.data.count > 0, "Articles list should be returned.")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user when signed out news are disabled`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "robsontemulop")
            _ = try await application.createArticle(userId: user.requireID(), title: "Disabled  robsontemulop", body: "Article body", visibility: .signOutNews)
            try await application.updateSetting(key: .showNewsForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/articles?visibility=signOutNews",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user and signed in news visibility`() async throws {

            // Act.
            let response = try await application.getErrorResponse(
                to: "/articles?visibility=signInNews",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user and signed in home visibility`() async throws {

            // Act.
            let response = try await application.getErrorResponse(
                to: "/articles?visibility=signInHome",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test
        func `Unauthorized should be returned for unauthorized user without any visibility`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/articles", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
