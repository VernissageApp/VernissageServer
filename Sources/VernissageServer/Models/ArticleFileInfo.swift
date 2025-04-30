//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Basic information about file attached to article.
final class ArticleFileInfo: Model, @unchecked Sendable {
    static let schema: String = "ArticleFileInfos"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "articleId")
    var article: Article
    
    @Field(key: "fileName")
    var fileName: String
    
    @Field(key: "width")
    var width: Int
    
    @Field(key: "height")
    var height: Int
        
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64,
                     articleId: Int64,
                     fileName: String,
                     width: Int,
                     height: Int) {
        self.init()

        self.id = id
        self.$article.id = articleId
        self.fileName = fileName
        self.width = width
        self.height = height
    }
}

/// Allows `ArticleFileInfo` to be encoded to and decoded from HTTP messages.
extension ArticleFileInfo: Content { }
