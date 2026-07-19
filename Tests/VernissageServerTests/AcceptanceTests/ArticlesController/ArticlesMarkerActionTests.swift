//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Testing
import Vapor

extension ControllersTests {

    @Suite("Articles (POST /articles/marker/:id/:language)", .serialized, .tags(.articles))
    struct ArticlesMarkerActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Marker should be created for authorized user and sign in news article`() async throws {
            // Arrange.
            let reader = try await application.createUser(userName: "articlesmarkerreader")
            let author = try await application.createUser(userName: "articlesmarkerauthor")
            let article = try await application.createArticle(
                userId: author.requireID(),
                title: "News article",
                body: "News body",
                visibility: .signInNews,
                language: "pl"
            )

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "articlesmarkerreader", password: "p@ssword"),
                to: "/articles/marker/\(article.stringId() ?? "")/PL",
                method: .POST
            )

            // Assert.
            #expect(response.status == .ok, "Response HTTP status code should be ok (200).")
            let articleMarker = try #require(await application.getArticleMarker(user: reader, language: "pl"))
            #expect(articleMarker.$article.id == article.id, "Correct article marker should be saved.")
            #expect(articleMarker.language == "pl", "Marker should store the selected language.")
        }

        @Test
        func `Existing marker should be updated`() async throws {
            // Arrange.
            let reader = try await application.createUser(userName: "articlesmarkerupdate")
            let author = try await application.createUser(userName: "articlesmarkerupauthor")
            let firstArticle = try await application.createArticle(
                userId: author.requireID(),
                title: "First news article",
                body: "First news body",
                visibility: .signInNews,
                language: "pl"
            )
            let secondArticle = try await application.createArticle(
                userId: author.requireID(),
                title: "Second news article",
                body: "Second news body",
                visibility: .signInNews,
                language: "pl"
            )
            let originalMarker = try await application.createArticleMarker(user: reader, article: firstArticle, language: "pl")

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "articlesmarkerupdate", password: "p@ssword"),
                to: "/articles/marker/\(secondArticle.stringId() ?? "")/pl",
                method: .POST
            )

            // Assert.
            #expect(response.status == .ok, "Response HTTP status code should be ok (200).")
            let articleMarker = try #require(await application.getArticleMarker(user: reader, language: "pl"))
            #expect(articleMarker.id == originalMarker.id, "Existing marker should be updated instead of creating a new one.")
            #expect(articleMarker.$article.id == secondArticle.id, "Marker should point at the selected article.")
        }

        @Test
        func `Marker should not be saved for article outside sign in news`() async throws {
            // Arrange.
            let reader = try await application.createUser(userName: "articlesmarkervisible")
            let author = try await application.createUser(userName: "articlesmarkervisauth")
            let article = try await application.createArticle(
                userId: author.requireID(),
                title: "Home article",
                body: "Home body",
                visibility: .signInHome,
                language: "pl"
            )

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "articlesmarkervisible", password: "p@ssword"),
                to: "/articles/marker/\(article.stringId() ?? "")/pl",
                method: .POST
            )

            // Assert.
            #expect(response.status == .notFound, "Response HTTP status code should be not found (404).")
            let articleMarker = try await application.getArticleMarker(user: reader, language: "pl")
            #expect(articleMarker == nil, "Marker should not be created for an article outside sign-in news.")
        }

        @Test
        func `Marker should use English US when language is omitted`() async throws {
            // Arrange.
            let reader = try await application.createUser(userName: "articlesmarkerdefault")
            let author = try await application.createUser(userName: "articlesmarkerdefauthor")
            let article = try await application.createArticle(
                userId: author.requireID(),
                title: "English news article",
                body: "English news body",
                visibility: .signInNews,
                language: "en_us"
            )

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "articlesmarkerdefault", password: "p@ssword"),
                to: "/articles/marker/\(article.stringId() ?? "")",
                method: .POST
            )

            // Assert.
            #expect(response.status == .ok, "Response HTTP status code should be ok (200).")
            let articleMarker = try #require(await application.getArticleMarker(user: reader))
            #expect(articleMarker.language == ArticleMarker.defaultLanguage.lowercased(), "Marker should store the default language in lowercase.")
        }

        @Test
        func `Markers should be stored separately for each language`() async throws {
            // Arrange.
            let reader = try await application.createUser(userName: "articlesmarkermulti")
            let author = try await application.createUser(userName: "articlesmarkermultiauth")
            let englishArticle = try await application.createArticle(
                userId: author.requireID(),
                title: "English article",
                body: "English body",
                visibility: .signInNews,
                language: "en_us"
            )
            let polishArticle = try await application.createArticle(
                userId: author.requireID(),
                title: "Polish article",
                body: "Polish body",
                visibility: .signInNews,
                language: "pl"
            )
            _ = try await application.createArticleMarker(user: reader, article: englishArticle)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "articlesmarkermulti", password: "p@ssword"),
                to: "/articles/marker/\(polishArticle.stringId() ?? "")/pl",
                method: .POST
            )

            // Assert.
            #expect(response.status == .ok, "Response HTTP status code should be ok (200).")
            let englishMarker = try #require(await application.getArticleMarker(user: reader))
            let polishMarker = try #require(await application.getArticleMarker(user: reader, language: "pl"))
            #expect(englishMarker.$article.id == englishArticle.id, "English marker should remain unchanged.")
            #expect(polishMarker.$article.id == polishArticle.id, "Polish marker should be created separately.")
        }

        @Test
        func `Marker should not be updated for unauthorized user`() async throws {
            // Act.
            let response = try await application.sendRequest(
                to: "/articles/marker/63363",
                method: .POST
            )

            // Assert.
            #expect(response.status == .unauthorized, "Response HTTP status code should be unauthorized (401).")
        }
    }
}
