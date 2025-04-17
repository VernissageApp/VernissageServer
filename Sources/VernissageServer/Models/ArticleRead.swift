//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Information about articles read by the user (and dismissed from the view).
final class ArticleRead: Model, @unchecked Sendable {
    static let schema: String = "ArticleReads"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "userId")
    var user: User
    
    @Parent(key: "articleId")
    var article: Article
            
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }

    convenience init(id: Int64, userId: Int64, articleId: Int64) {
        self.init()

        self.id = id
        self.$user.id = userId
        self.$article.id = articleId
    }
}

/// Allows `ArticleRead` to be encoded to and decoded from HTTP messages.
extension ArticleRead: Content { }
