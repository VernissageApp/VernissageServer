//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User's business card.
final class BusinessCard: Model, @unchecked Sendable {
    static let schema: String = "BusinessCards"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "userId")
    var user: User
        
    @Field(key: "title")
    var title: String

    @Field(key: "subtitle")
    var subtitle: String?
    
    @Field(key: "body")
    var body: String?

    @Field(key: "website")
    var website: String?
    
    @Field(key: "telephone")
    var telephone: String?
    
    @Field(key: "email")
    var email: String?
    
    @Field(key: "color1")
    var color1: String

    @Field(key: "color2")
    var color2: String

    @Field(key: "color3")
    var color3: String
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    @Children(for: \.$businessCard)
    var businessCardFields: [BusinessCardField]
    
    @Children(for: \.$businessCard)
    var sharedBusinessCards: [SharedBusinessCard]
    
    init() { }

    convenience init(id: Int64,
                     userId: Int64,
                     title: String,
                     subtitle: String? = nil,
                     body: String? = nil,
                     website: String? = nil,
                     telephone: String? = nil,
                     email: String? = nil,
                     color1: String,
                     color2: String,
                     color3: String
    ) {
        self.init()

        self.id = id
        self.$user.id = userId
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.website = website
        self.telephone = telephone
        self.email = email
        self.color1 = color1
        self.color2 = color2
        self.color3 = color3
    }
}

/// Allows `BusinessCard` to be encoded to and decoded from HTTP messages.
extension BusinessCard: Content { }
