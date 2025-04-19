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
        
        @Test("Article should be returned for moderator user")
        func articleShouldBeReturnedForModeratorUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictortronch")
            try await application.attach(user: user, role: Role.moderator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .news)
            
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
        
        @Test("Article should be returned for administrator user")
        func articleShouldBeReturnedForAdministratorUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "adamtronch")
            try await application.attach(user: user, role: Role.administrator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .news)
            
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

        @Test("Article should be returned for not authorized user and signed out visibility")
        func articleShouldBeReturnedForNotAuthorizedUserAndSignedOutVisibility() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "boristronch")
            try await application.attach(user: user, role: Role.administrator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signOutHome)
            
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
        
        @Test("Unauthorized should be returned for not authorized user and not signed out visibility")
        func unauthorizedShouldBeReturendForNotAuthorizedUserAndNotSignedOutVisibility() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "martintronch")
            try await application.attach(user: user, role: Role.administrator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .news)

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
