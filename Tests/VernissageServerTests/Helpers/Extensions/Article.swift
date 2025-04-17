//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func createArticle(userId: Int64, title: String, body: String, visibility: ArticleVisibilityType) async throws -> Article {
        let id = await ApplicationManager.shared.generateId()
        let article = Article(id: id, userId: userId, title: title, body: body)
        try await article.save(on: self.db)
        
        let visibilityId = await ApplicationManager.shared.generateId()
        let articleVisibility = ArticleVisibility(id: visibilityId, articleId: id, articleVisibilityType: visibility)
        try await articleVisibility.save(on: self.db)

        return article
    }
    
    func getAllArticles(userId: Int64) async throws -> [Article] {
        return try await Article.query(on: self.db)
            .with(\.$user)
            .with(\.$articleVisibilities)
            .filter(\.$user.$id == userId)
            .all()
    }
    
    func createArticleRead(userId: Int64, articleId: Int64) async throws -> ArticleRead {
        let id = await ApplicationManager.shared.generateId()
        let articleRead = ArticleRead(id: id, userId: userId, articleId: articleId)
        try await articleRead.save(on: self.db)
        
        return articleRead
    }
    
    func getAllArticleReads(userId: Int64) async throws -> [ArticleRead] {
        return try await ArticleRead.query(on: self.db)
            .filter(\.$user.$id == userId)
            .all()
    }
}
