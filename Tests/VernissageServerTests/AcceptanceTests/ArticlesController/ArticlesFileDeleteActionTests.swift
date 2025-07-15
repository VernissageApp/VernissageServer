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
    
    @Suite("Articles (DELETE /articles/:id/file)", .serialized, .tags(.articles))
    struct ArticlesFileDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("File should be deleted from article for authorized user")
        func fileShouldBeDeletedFromArticleForAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "larafromia")
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

            let _ = try await application.sendRequest(
                as: .user(userName: "larafromia", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            let articleFromDatabase = try await application.getArticle(articleId: article.requireID())
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "larafromia", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file/\(articleFromDatabase?.articleFileInfos.first?.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let articleFromDatabaseAfterDelete = try await application.getArticle(articleId: article.requireID())
            #expect(articleFromDatabaseAfterDelete != nil, "Article should be saved.")
            #expect(articleFromDatabaseAfterDelete?.articleFileInfos.count == 0, "Article file should be deleted.")
        }
        
        
        @Test("File should not be deleted from article for regular user")
        func fileShouldNotBeDeletedFromArticleForRegularUser() async throws {
            
            // Arrange.
            let _ = try await application.createUser(userName: "monikafromia")
            let user = try await application.createUser(userName: "renatafromia")
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

            let _ = try await application.sendRequest(
                as: .user(userName: "renatafromia", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            let articleFromDatabase = try await application.getArticle(articleId: article.requireID())
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "monikafromia", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file/\(articleFromDatabase?.articleFileInfos.first?.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("File should not be deleted from article for anonymous user")
        func fileShouldNotBeDeletedFromArticleForAnonymousUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robertfromia")
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

            let _ = try await application.sendRequest(
                as: .user(userName: "robertfromia", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            let articleFromDatabase = try await application.getArticle(articleId: article.requireID())
            
            // Act.
            let response = try await application.sendRequest(
                to: "/articles/" + (article.stringId() ?? "") + "/file/\(articleFromDatabase?.articleFileInfos.first?.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("File should not be deleted when article id is invalid")
        func fileShouldNotBeDeletedWhenArticleIdIsInvalid() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "erykfromia")
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

            let _ = try await application.sendRequest(
                as: .user(userName: "erykfromia", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            let articleFromDatabase = try await application.getArticle(articleId: article.requireID())
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "erykfromia", password: "p@ssword"),
                to: "/articles/aaaa/file/\(articleFromDatabase?.articleFileInfos.first?.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be badRequest (400).")
        }
        
        @Test("File should not be deleted when article file id is invalid")
        func fileShouldNotBeDeletedWhenArticleFileIdIsInvalid() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "ryszardfromia")
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

            let _ = try await application.sendRequest(
                as: .user(userName: "ryszardfromia", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
                        
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "ryszardfromia", password: "p@ssword"),
                to: "/articles/\(article.stringId() ?? "")/file/bbbb",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be badRequest (400).")
        }
        
        @Test("File should not be deleted when article not found")
        func fileShouldNotBeDeletedWhenArticleNotFound() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "arnoldfromia")
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

            let _ = try await application.sendRequest(
                as: .user(userName: "arnoldfromia", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            let articleFromDatabase = try await application.getArticle(articleId: article.requireID())
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "arnoldfromia", password: "p@ssword"),
                to: "/articles/123/file/\(articleFromDatabase?.articleFileInfos.first?.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
        
        @Test("File should not be deleted when article file not found")
        func fileShouldNotBeDeletedWhenArticleFileNotFound() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "frankfromia")
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

            let _ = try await application.sendRequest(
                as: .user(userName: "frankfromia", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
                        
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "frankfromia", password: "p@ssword"),
                to: "/articles/\(article.stringId() ?? "")/file/123",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be notFound (404).")
        }
        
        @Test("File should not be deleted when article is not connected with file")
        func fileShouldNotBeDeletedWhenArticleIsNotConnectedWithFile() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "piotrfromia")
            try await application.attach(user: user, role: Role.moderator)
            
            let article = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await article.save(on: self.application.db)

            let article2 = try await application.createArticle(userId: user.requireID(), title: "Title", body: "Article body", visibility: .signInNews)
            try await article2.save(on: self.application.db)
            
            let fileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/articles/\(article.stringId() ?? "")")
            defer{
                try? FileManager.default.removeItem(at: fileUrl)
            }
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")

            let _ = try await application.sendRequest(
                as: .user(userName: "piotrfromia", password: "p@ssword"),
                to: "/articles/" + (article.stringId() ?? "") + "/file",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            let articleFromDatabase = try await application.getArticle(articleId: article.requireID())
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "piotrfromia", password: "p@ssword"),
                to: "/articles/\(article2.stringId() ?? "")/file/\(articleFromDatabase?.articleFileInfos.first?.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be badRequest (400).")
        }
    }
}
