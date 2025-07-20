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
    
    @Suite("Articles (POST /articles/:id/file/:fileId/main)", .serialized, .tags(.articles))
    struct ArticlesMainFileActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("File should be marked as main for an article")
        func fileShouldBeMarkedAsMainForAnArticle() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "larafunio")
            try await application.attach(user: user, role: Role.moderator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            let fileInfo = try await application.createArticleFileInfo(articleId: article.requireID(), fileName: "file.png", width: 100, heigth: 200)
            
            article.$mainArticleFileInfo.id = try fileInfo.requireID()
            try await article.save(on: self.application.db)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "larafunio", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file/" + (fileInfo.stringId() ?? "") + "/main",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let articleFromDatabase = try await application.getArticle(articleId: article.requireID())
            #expect(articleFromDatabase?.$mainArticleFileInfo.id == fileInfo.id, "File should be marked as main.")
        }
        
        @Test("File should not be marked as main for regular user")
        func fileShouldNotBeMarkedAsMainForRegularUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "annafunio")
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            let fileInfo = try await application.createArticleFileInfo(articleId: article.requireID(), fileName: "file.png", width: 100, heigth: 200)
            
            article.$mainArticleFileInfo.id = try fileInfo.requireID()
            try await article.save(on: self.application.db)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "annafunio", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file/" + (fileInfo.stringId() ?? "") + "/main",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("File should not be marked as main for anonymous user")
        func fileShouldNotBeMarkedAsMainForAnonymousUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robertfunio")
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            let fileInfo = try await application.createArticleFileInfo(articleId: article.requireID(), fileName: "file.png", width: 100, heigth: 200)
            
            article.$mainArticleFileInfo.id = try fileInfo.requireID()
            try await article.save(on: self.application.db)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/articles/" + (article.stringId() ?? "") + "/file/" + (fileInfo.stringId() ?? "") + "/main",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("File should not be marked as main for invalid article id")
        func fileShouldNotBeMarkedAsMainForInvalidArticleId() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "trondfunio")
            try await application.attach(user: user, role: Role.moderator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            let fileInfo = try await application.createArticleFileInfo(articleId: article.requireID(), fileName: "file.png", width: 100, heigth: 200)
            
            article.$mainArticleFileInfo.id = try fileInfo.requireID()
            try await article.save(on: self.application.db)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "trondfunio", password: "p@ssword"),
                to: "/articles/aaa/file/" + (fileInfo.stringId() ?? "") + "/main",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be badRequest (400).")
        }
        
        @Test("File should not be marked as main for invalid file id")
        func fileShouldNotBeMarkedAsMainForInvalidFileId() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "hanryfunio")
            try await application.attach(user: user, role: Role.moderator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            let fileInfo = try await application.createArticleFileInfo(articleId: article.requireID(), fileName: "file.png", width: 100, heigth: 200)
            
            article.$mainArticleFileInfo.id = try fileInfo.requireID()
            try await article.save(on: self.application.db)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "hanryfunio", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file/aaaa/main",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be badRequest (400).")
        }
        
        @Test("File should not be marked as main when article not exists")
        func fileShouldNotBeMarkedAsMainWhenArticleNotExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "monikafunio")
            try await application.attach(user: user, role: Role.moderator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            let fileInfo = try await application.createArticleFileInfo(articleId: article.requireID(), fileName: "file.png", width: 100, heigth: 200)
            
            article.$mainArticleFileInfo.id = try fileInfo.requireID()
            try await article.save(on: self.application.db)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "monikafunio", password: "p@ssword"),
                to: "/articles/123/file/" + (fileInfo.stringId() ?? "") + "/main",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
        
        @Test("File should not be marked as main when file not exists")
        func fileShouldNotBeMarkedAsMainWhenFileNotExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "benfunio")
            try await application.attach(user: user, role: Role.moderator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            let fileInfo = try await application.createArticleFileInfo(articleId: article.requireID(), fileName: "file.png", width: 100, heigth: 200)
            
            article.$mainArticleFileInfo.id = try fileInfo.requireID()
            try await article.save(on: self.application.db)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "benfunio", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file/123/main",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
        
        @Test("File should not be marked as main when file is not connected to article")
        func fileShouldNotBeMarkedAsMainWhenFileIsNotConnectedToArticle() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "viktorfunio")
            try await application.attach(user: user, role: Role.moderator)
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            let fileInfo = try await application.createArticleFileInfo(articleId: article.requireID(), fileName: "file.png", width: 100, heigth: 200)
            let article2 = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            
            article.$mainArticleFileInfo.id = try fileInfo.requireID()
            try await article.save(on: self.application.db)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "viktorfunio", password: "p@ssword"),
                to: "/articles/" + (article2.stringId() ?? "") + "/file/\(fileInfo.stringId() ?? "")/main",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be badRequest (400).")
        }
    }
}
