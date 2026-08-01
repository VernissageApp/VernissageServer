//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Camera information extracted from image EXIF metadata.
final class Camera: Model, @unchecked Sendable {
    static let schema: String = "Cameras"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "name")
    var name: String

    @Field(key: "nameNormalized")
    var nameNormalized: String

    @Field(key: "make")
    var make: String?

    @Field(key: "model")
    var model: String?

    @Field(key: "amount")
    var amount: Int

    @Siblings(through: CameraStatus.self, from: \.$id.$camera, to: \.$id.$status)
    var statuses: [Status]

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, name: String, make: String? = nil, model: String? = nil, amount: Int = 0) {
        self.init()

        self.id = id
        self.name = name
        self.nameNormalized = name.trimmingCharacters(in: CharacterSet(charactersIn: " ")).uppercased()
        self.make = make
        self.model = model
        self.amount = amount
    }
}

/// Allows `Camera` to be encoded to and decoded from HTTP messages.
extension Camera: Content { }
