//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Article with text.
final class Article: Model, @unchecked Sendable {
    static let schema: String = "Articles"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "userId")
    var user: User
        
    @Field(key: "title")
    var title: String?
    
    @Field(key: "body")
    var body: String

    @Field(key: "color")
    var color: String?

    @Field(key: "alternativeAuthor")
    var alternativeAuthor: String?
    
    @OptionalParent(key: "mainArticleFileInfoId")
    var mainArticleFileInfo: ArticleFileInfo?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    @Children(for: \.$article)
    var articleVisibilities: [ArticleVisibility]

    @Children(for: \.$article)
    var articleFileInfos: [ArticleFileInfo]
    
    init() { }

    convenience init(id: Int64,
                     userId: Int64,
                     title: String? = nil,
                     body: String,
                     color: String? = nil,
                     alternativeAuthor: String? = nil,
                     mainArticleFileInfo: Int64? = nil
    ) {
        self.init()

        self.id = id
        self.$user.id = userId
        self.$mainArticleFileInfo.id = mainArticleFileInfo
        self.title = title
        self.body = body
        self.color = color
        self.alternativeAuthor = alternativeAuthor
    }
}

/// Allows `Article` to be encoded to and decoded from HTTP messages.
extension Article: Content { }
