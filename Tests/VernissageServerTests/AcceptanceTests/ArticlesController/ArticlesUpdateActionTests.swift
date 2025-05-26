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
    
    @Suite("Articles (PUT /articles/:id)", .serialized, .tags(.articles))
    struct ArticlesUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Article should be updated by authorized user")
        func articleShouldBeUpdatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laragodzirra")
            try await application.attach(user: user, role: Role.moderator)
            
            let article = try await application.createArticle(userId: user.requireID(), title: "Title #002", body: "Body #002", visibility: .signInNews)
            let articleDto = ArticleDto(id: article.stringId(),
                                        title: "Changed Title #002",
                                        body: "Changed Body #002",
                                        color: "#FFFFFF",
                                        alternativeAuthor: "@johndoe@example.com",
                                        user: nil,
                                        mainArticleFileInfo: nil,
                                        visibilities: [.signInNews, .signInHome])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laragodzirra", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? ""),
                method: .PUT,
                body: articleDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let articles = try await application.getAllArticles(userId: user.requireID())
            #expect(articles.first?.title == "Changed Title #002", "Title should be set correctly.")
            #expect(articles.first?.body == "Changed Body #002", "Body should be set correctly.")
            #expect(articles.first?.color == "#FFFFFF", "Color should be set correctly.")
            #expect(articles.first?.alternativeAuthor == "@johndoe@example.com", "Altarnative authir should be set correctly.")
            #expect(articles.first?.articleVisibilities.count == 2, "Visibilities should be set correctly.")
        }
        
        @Test("Article should not be updated if body was not specified")
        func articleShouldNotBeUpdatedIfBodyWasNotSpecified() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikogodzirra")
            try await application.attach(user: user, role: Role.moderator)
            
            let article = try await application.createArticle(userId: user.requireID(), title: "Title #003", body: "Body #003", visibility: .signInNews)
            let articleDto = ArticleDto(id: article.stringId(),
                                        title: "Changed Title #003",
                                        body: "",
                                        user: nil,
                                        mainArticleFileInfo: nil,
                                        visibilities: [.signInNews, .signInHome])
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikogodzirra", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? ""),
                method: .PUT,
                data: articleDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("body") == "is less than minimum of 1 character(s)")
        }
        
        @Test("Article should not be updated if title is too long")
        func articleShouldNotBeUpdatedIfTitleIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robogodzirra")
            try await application.attach(user: user, role: Role.moderator)
                        
            let article = try await application.createArticle(userId: user.requireID(), title: "Title #003", body: "Body #002", visibility: .signInNews)
            let articleDto = ArticleDto(id: article.stringId(),
                                        title: String.createRandomString(length: 201),
                                        body: "Changed Body #003",
                                        user: nil,
                                        mainArticleFileInfo: nil,
                                        visibilities: [.signInNews, .signInHome])
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robogodzirra", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? ""),
                method: .PUT,
                data: articleDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is greater than maximum of 200 character(s) and is not null")
        }
        
        @Test("Article should not be updated if alternative author is too long")
        func articleShouldNotBeUpdatedIfAlternativeAuthorIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "roxogodzirra")
            try await application.attach(user: user, role: Role.moderator)
                        
            let article = try await application.createArticle(userId: user.requireID(), title: "Title #003", body: "Body #002", visibility: .signInNews)
            let articleDto = ArticleDto(id: article.stringId(),
                                        title: "title",
                                        body: "Changed Body #003",
                                        alternativeAuthor: String.createRandomString(length: 501),
                                        user: nil,
                                        mainArticleFileInfo: nil,
                                        visibilities: [.signInNews, .signInHome])
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "roxogodzirra", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? ""),
                method: .PUT,
                data: articleDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("alternativeAuthor") == "is greater than maximum of 500 character(s) and is not null")
        }
                
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldBeReturneddForRegularUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nogogodzirra")

            let article = try await application.createArticle(userId: user.requireID(), title: "Title #002", body: "Body #002", visibility: .signInNews)
            let articleDto = ArticleDto(id: article.stringId(),
                                        title: "Changed Title #002",
                                        body: "Changed Body #002",
                                        user: nil,
                                        mainArticleFileInfo: nil,
                                        visibilities: [.signInNews, .signInHome])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogogodzirra", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? ""),
                method: .PUT,
                body: articleDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "tromgodzirra")

            let article = try await application.createArticle(userId: user.requireID(), title: "Title #002", body: "Body #002", visibility: .signInNews)
            let articleDto = ArticleDto(id: article.stringId(),
                                        title: "Changed Title #002",
                                        body: "Changed Body #002",
                                        user: nil,
                                        mainArticleFileInfo: nil,
                                        visibilities: [.signInNews, .signInHome])
            
            // Act.
            let response = try await application.sendRequest(
                to: "/articles/" + (article.stringId() ?? ""),
                method: .PUT,
                body: articleDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
