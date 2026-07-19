//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Vapor

extension Application {
    func createArticleMarker(
        user: User,
        article: Article,
        language: String = ArticleMarker.defaultLanguage
    ) async throws -> ArticleMarker {
        let id = await ApplicationManager.shared.generateId()
        let articleMarker = try ArticleMarker(
            id: id,
            articleId: article.requireID(),
            userId: user.requireID(),
            language: language
        )
        try await articleMarker.save(on: self.db)
        return articleMarker
    }

    func getArticleMarker(
        user: User,
        language: String = ArticleMarker.defaultLanguage
    ) async throws -> ArticleMarker? {
        return try await ArticleMarker.query(on: self.db)
            .filter(\.$user.$id == user.requireID())
            .filter(\.$language == language.lowercased())
            .with(\.$article)
            .first()
    }
}
