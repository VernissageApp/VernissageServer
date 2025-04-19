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
    
    @Suite("Articles (PUT /articles/:id/dismiss)", .serialized, .tags(.articles))
    struct ArticlesDismissActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Article should be dismissed by authorized user")
        func articleShouldBeDismissedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "lararolok")
            let article = try await application.createArticle(userId: user.requireID(), title: "Title #002", body: "Body #002", visibility: .news)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "lararolok", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/dismiss",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let articleReads = try await application.getAllArticleReads(userId: user.requireID())
            #expect(articleReads.count == 1, "Article should be dismissed")
        }
                                        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "tromrolok")
            let article = try await application.createArticle(userId: user.requireID(), title: "Title #002", body: "Body #002", visibility: .news)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/articles/" + (article.stringId() ?? "") + "/dismiss",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
