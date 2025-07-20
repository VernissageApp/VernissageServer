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
    
    @Suite("Articles (POST /articles/:id/file)", .serialized, .tags(.articles))
    struct ArticlesFileUploadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("File should be uploaded article for authorized user")
        func fileShouldBeUploadedToArticleForAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laratoniak")
            try await application.attach(user: user, role: Role.moderator)

            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await article.save(on: self.application.db)
            
            let fileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/articles/\(article.stringId() ?? "")")
            defer{
                try? FileManager.default.removeItem(at: fileUrl)
            }
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laratoniak", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let articleFromDatabase = try await application.getArticle(articleId: article.requireID())
            #expect(articleFromDatabase != nil, "Article should be saved.")
            #expect(articleFromDatabase?.articleFileInfos.count == 1, "Article file should be saved.")
        }
        
        @Test("File should not be uploaded article for regular user")
        func fileShouldNotBeUploadedToArticleForRegularUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "monikatoniak")

            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await article.save(on: self.application.db)
                        
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "monikatoniak", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("File should not be uploaded article for anonymous user")
        func fileShouldNotBeUploadedToArticleForAnonymousUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "wiktortoniak")

            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await article.save(on: self.application.db)
                        
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/articles/" + (article.stringId() ?? "") + "/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("File should not be uploaded when article id is incorrect")
        func fileShouldNotBeUploadedWhenArticleIdIsIncorrect() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "grzegorztoniak")
            try await application.attach(user: user, role: Role.moderator)

            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await article.save(on: self.application.db)
                        
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "grzegorztoniak", password: "p@ssword"),
                to: "/articles/aaa/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be badRequest (400).")
        }
        
        @Test("File should not be uploaded when article not found")
        func fileShouldNotBeUploadedWhenArticleNotFound() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "annatoniak")
            try await application.attach(user: user, role: Role.moderator)

            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await article.save(on: self.application.db)
                        
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "annatoniak", password: "p@ssword"),
                to: "/articles/111/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
        
        @Test("File should not be uploaded when file has not been attached")
        func fileShouldNotBeUploadedWhenFileHasNotBeenAttached() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "mariatoniak")
            try await application.attach(user: user, role: Role.moderator)

            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await article.save(on: self.application.db)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "mariatoniak", password: "p@ssword"),
                to: "/articles/\(article.stringId() ?? "")/file",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be badRequest (400).")
        }
    }
}
