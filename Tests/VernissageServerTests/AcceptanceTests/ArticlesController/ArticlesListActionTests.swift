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
        
        @Test("List of all articles should be returned for moderator user")
        func listOfArticlesShouldBeReturnedForModeratorUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictortemulop")
            try await application.attach(user: user, role: Role.moderator)
            _ = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .news)
            
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
        
        @Test("List of articles should be returned for administrator user")
        func listOfArticlesShouldBeReturnedForAdministratorUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "adamtemulop")
            try await application.attach(user: user, role: Role.administrator)
            _ = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .news)
            
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
        
        @Test("List of articles should be returned for regular user without dismissed")
        func listOfArticlesShouldBeReturnedForRegularUserWithoutDismissed() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "gorrrtemulop")
            _ = try await application.createArticle(userId: user.requireID(), title: "Title #1", body: "Article body", visibility: .news)
            let article = try await application.createArticle(userId: user.requireID(), title: "Dismissed title #1", body: "Article body", visibility: .news)
            _ = try await application.createArticleRead(userId: user.requireID(), articleId: article.requireID())
            
            // Act.
            let articles = try await application.getResponse(
                as: .user(userName: "gorrrtemulop", password: "p@ssword"),
                to: "/articles",
                method: .GET,
                decodeTo: PaginableResultDto<ArticleDto>.self
            )
            
            // Assert.
            #expect(articles.data.contains(where: { $0.title == "Dismissed title #1" }) == false, "Dismissed article should not be returned.")
        }
        
        @Test("List of articles should be returned for regular user with dismissed when dismissed flag is specified")
        func listOfArticlesShouldBeReturnedForRegularUserWithDismissedWhenDismissedFlaIsSpecified() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "dianatemulop")
            _ = try await application.createArticle(userId: user.requireID(), title: "Visible title #1", body: "Article body", visibility: .news)
            let article = try await application.createArticle(userId: user.requireID(), title: "Visible title #2 (dismissed)", body: "Article body", visibility: .news)
            _ = try await application.createArticleRead(userId: user.requireID(), articleId: article.requireID())
            
            // Act.
            let articles = try await application.getResponse(
                as: .user(userName: "dianatemulop", password: "p@ssword"),
                to: "/articles?dismissed=true",
                method: .GET,
                decodeTo: PaginableResultDto<ArticleDto>.self
            )
            
            // Assert.
            #expect(articles.data.contains(where: { $0.title == "Visible title #1" }), "Not dismissed article should be visible.")
            #expect(articles.data.contains(where: { $0.title == "Visible title #2 (dismissed)" }), "Dismissed article should be visible.")
        }

        @Test("List of articles should be returned for not authorized user and signed out visibility")
        func listOfArticlesShouldBeReturnedForNotAuthorizedUserAndSignedOutVisibility() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "borisemulop")
            try await application.attach(user: user, role: Role.administrator)
            _ = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signOutHome)
            
            // Act.
            let articles = try await application.getResponse(
                to: "/articles?visibility=signOutHome",
                method: .GET,
                decodeTo: PaginableResultDto<ArticleDto>.self
            )
            
            // Assert.
            #expect(articles.data.count > 0, "Articles list should be returned.")
        }
        
        @Test("Unauthorized should be returned for not authorized user and not signed out visibility")
        func unauthorizedShouldBeReturendForNotAuthorizedUserAndNotSignedOutVisibility() async throws {

            // Act.
            let response = try await application.getErrorResponse(
                to: "/articles?visibility=blog",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Unauthorized should be returned for regular user without any visibility")
        func unauthorizedShouldbeReturnedForRegularUserWithoutAnyVisibility() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/articles", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
