//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Film information extracted from image EXIF metadata.
final class Film: Model, @unchecked Sendable {
    static let schema: String = "Films"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "name")
    var name: String

    @Field(key: "nameNormalized")
    var nameNormalized: String

    @Field(key: "amount")
    var amount: Int

    @Siblings(through: FilmStatus.self, from: \.$id.$film, to: \.$id.$status)
    var statuses: [Status]

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, name: String, amount: Int = 0) {
        self.init()

        self.id = id
        self.name = name
        self.nameNormalized = name.trimmingCharacters(in: CharacterSet(charactersIn: " ")).uppercased()
        self.amount = amount
    }
}

/// Allows `Film` to be encoded to and decoded from HTTP messages.
extension Film: Content { }
