//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Article with text.
final class ArticleVisibility: Model, @unchecked Sendable {
    static let schema: String = "ArticleVisibilities"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "articleId")
    var article: Article
        
    @Field(key: "articleVisibilityType")
    var articleVisibilityType: ArticleVisibilityType
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, articleId: Int64, articleVisibilityType: ArticleVisibilityType) {
        self.init()

        self.id = id
        self.$article.id = articleId
        self.articleVisibilityType = articleVisibilityType
    }
}

/// Allows `ArticleVisibility` to be encoded to and decoded from HTTP messages.
extension ArticleVisibility: Content { }
