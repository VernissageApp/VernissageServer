//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct UserBlockedDomainDto {
    var id: String?
    var domain: String
    var reason: String?
    var createdAt: Date?
    var updatedAt: Date?
}

extension UserBlockedDomainDto {
    init(from userBlockedDomain: UserBlockedDomain) {
        self.init(id: userBlockedDomain.stringId(),
                  domain: userBlockedDomain.domain,
                  reason: userBlockedDomain.reason,
                  createdAt: userBlockedDomain.createdAt,
                  updatedAt: userBlockedDomain.updatedAt)
    }
}

extension UserBlockedDomainDto: Content { }

extension UserBlockedDomainDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("domain", as: String.self, is: .count(1...500), required: true)
        validations.add("reason", as: String?.self, is: .nil || .count(...500), required: false)
    }
}
