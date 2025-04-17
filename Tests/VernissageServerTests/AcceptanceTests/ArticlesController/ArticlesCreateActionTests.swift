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
    
    @Suite("Articles (POST /articles)", .serialized, .tags(.articles))
    struct ArticlesCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Article should be created by authorized user")
        func articleShouldBeCreatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "larabobsox")
            try await application.attach(user: user, role: Role.moderator)
                        
            let articleDto = ArticleDto(title: "Article #001", body: "Body #001", color: "#00ff00", user: nil, visibilities: [.news, .signInHome])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "larabobsox", password: "p@ssword"),
                to: "/articles",
                method: .POST,
                body: articleDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let articles = try await application.getAllArticles(userId: user.requireID())
            #expect(articles.count == 1, "Article should be added to the database.")
            #expect(articles.first?.title == "Article #001", "Article title should be saved.")
            #expect(articles.first?.body == "Body #001", "Article body should be saved.")
            #expect(articles.first?.color == "#00ff00", "Article color should be saved.")
            #expect(articles.first?.articleVisibilities.count == 2, "Article visibilities should be saved.")
        }
        
        @Test("Article should not be created if body was not specified")
        func articleShouldNotBeCreatedIfNameWasNotSpecified() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikobobsox")
            try await application.attach(user: user, role: Role.moderator)
            
            let articleDto = ArticleDto(title: "Article #001", body: "", user: nil, visibilities: [.news, .signInHome])
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikobobsox", password: "p@ssword"),
                to: "/articles",
                method: .POST,
                data: articleDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("body") == "is less than minimum of 1 character(s)")
        }
        
        @Test("Article should not be created if title is too long")
        func articleShouldNotBeCreatedIfTitleIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robbobsox")
            try await application.attach(user: user, role: Role.moderator)
            
            let articleDto = ArticleDto(title: String.createRandomString(length: 201), body: "", user: nil, visibilities: [.news, .signInHome])
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robbobsox", password: "p@ssword"),
                to: "/articles",
                method: .POST,
                data: articleDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is greater than maximum of 200 character(s) and is not null")
        }
                
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldBeReturneddForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogbobsox")
            let articleDto = ArticleDto(title: "Article #001", body: "Body #001", user: nil, visibilities: [.news, .signInHome])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogbobsox", password: "p@ssword"),
                to: "/articles",
                method: .POST,
                body: articleDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let articleDto = ArticleDto(title: "Article #001", body: "Body #001", user: nil, visibilities: [.news, .signInHome])
            
            // Act.
            let response = try await application.sendRequest(
                to: "/articles",
                method: .POST,
                body: articleDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
