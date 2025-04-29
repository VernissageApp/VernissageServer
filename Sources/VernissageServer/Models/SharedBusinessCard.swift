//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User's business card made available to a third party.
final class SharedBusinessCard: Model, @unchecked Sendable {
    static let schema: String = "SharedBusinessCards"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "businessCardId")
    var businessCard: BusinessCard

    @Field(key: "code")
    var code: String
    
    @Field(key: "title")
    var title: String

    @Field(key: "note")
    var note: String?
    
    @Field(key: "thirdPartyName")
    var thirdPartyName: String

    @Field(key: "thirdPartyEmail")
    var thirdPartyEmail: String?

    @Timestamp(key: "revokedAt", on: .none)
    var revokedAt: Date?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    @Children(for: \.$sharedBusinessCard)
    var messages: [SharedBusinessCardMessage]
    
    init() { }

    convenience init(id: Int64,
                     businessCardId: Int64,
                     code: String,
                     title: String,
                     note: String? = nil,
                     thirdPartyName: String,
                     thirdPartyEmail: String? = nil
    ) {
        self.init()

        self.id = id
        self.$businessCard.id = businessCardId
        self.code = code
        self.title = title
        self.note = note
        self.thirdPartyName = thirdPartyName
        self.thirdPartyEmail = thirdPartyEmail
    }
}

/// Allows `SharedBusinessCard` to be encoded to and decoded from HTTP messages.
extension SharedBusinessCard: Content { }
