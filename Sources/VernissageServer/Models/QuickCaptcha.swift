//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Quick captcha codes.
final class QuickCaptcha: Model, @unchecked Sendable {
    static let schema = "QuickCaptchas"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "key")
    var key: String
    
    @Field(key: "text")
    var text: String

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    convenience init(id: Int64,
                     key: String,
                     text: String
    ) {
        self.init()

        self.id = id
        self.key = key
        self.text = text
    }
}

/// Allows `QuickCaptcha` to be encoded to and decoded from HTTP messages.
extension QuickCaptcha: Content { }
