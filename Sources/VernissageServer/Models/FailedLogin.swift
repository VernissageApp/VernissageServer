//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Information about failed login attempt.
final class FailedLogin: Model, @unchecked Sendable {
    static let schema: String = "FailedLogins"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "userName")
    var userName: String

    @Field(key: "userNameNormalized")
    var userNameNormalized: String

    @Field(key: "ip")
    var ip: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, userName: String, ip: String?) {
        self.init()

        self.id = id
        self.userName = userName
        self.userNameNormalized = userName.uppercased()
        self.ip = ip
    }
}

/// Allows `FailedLogin` to be encoded to and decoded from HTTP messages.
extension FailedLogin: Content { }
