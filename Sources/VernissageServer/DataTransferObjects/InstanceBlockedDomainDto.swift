//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct InstanceBlockedDomainDto {
    var id: String?
    var domain: String
    var reason: String?
    var createdAt: Date?
    var updatedAt: Date?
}

extension InstanceBlockedDomainDto {
    init(from instanceBlockedDomain: InstanceBlockedDomain) {
        self.init(id: instanceBlockedDomain.stringId(),
                  domain: instanceBlockedDomain.domain,
                  reason: instanceBlockedDomain.reason,
                  createdAt: instanceBlockedDomain.createdAt,
                  updatedAt: instanceBlockedDomain.updatedAt)
    }
}

extension InstanceBlockedDomainDto: Content { }

extension InstanceBlockedDomainDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("domain", as: String.self, is: .count(1...500), required: true)
        validations.add("reason", as: String?.self, is: .nil || .count(...500), required: false)
    }
}
