//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Servers suspended after connection related errors.
final class SuspendedServer: Model, @unchecked Sendable {
    static let schema: String = "SuspendedServers"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "host")
    var host: String

    @Field(key: "hostNormalized")
    var hostNormalized: String

    @Field(key: "numberOfErrors")
    var numberOfErrors: Int

    @Field(key: "lastErrorDate")
    var lastErrorDate: Date

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, host: String, numberOfErrors: Int, lastErrorDate: Date) {
        self.init()

        self.id = id
        self.host = host
        self.hostNormalized = host.uppercased()
        self.numberOfErrors = numberOfErrors
        self.lastErrorDate = lastErrorDate
    }
}

/// Allows `SuspendedServer` to be encoded to and decoded from HTTP messages.
extension SuspendedServer: Content { }
