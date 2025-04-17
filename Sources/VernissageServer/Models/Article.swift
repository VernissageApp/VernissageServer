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
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    @Children(for: \.$article)
    var articleVisibilities: [ArticleVisibility]
    
    init() { }

    convenience init(id: Int64, userId: Int64, title: String? = nil, body: String, color: String? = nil) {
        self.init()

        self.id = id
        self.$user.id = userId
        self.title = title
        self.body = body
        self.color = color
    }
}

/// Allows `Article` to be encoded to and decoded from HTTP messages.
extension Article: Content { }
