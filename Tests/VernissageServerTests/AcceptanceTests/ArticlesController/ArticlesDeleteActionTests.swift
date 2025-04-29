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
    
    @Suite("Articles (DELETE /articles/:id)", .serialized, .tags(.articles))
    struct ArticlesDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Article should be deleted by authorized user")
        func articleShouldBeDeletedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laravonden")
            try await application.attach(user: user, role: Role.moderator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
                        
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laravonden", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let articles = try await application.getAllArticles(userId: user.requireID())
            #expect(articles.count == 0, "Article should be deleted.")
        }
                
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldBeReturneddForRegularUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nogovonden")
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogovonden", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "tromekvonden")
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/articles/" + (article.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
