//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct RoleDto {
    var id: String?
    var code: String
    var title: String
    var description: String?
    var isDefault: Bool = false
}

extension RoleDto {
    init(from role: Role) {
        self.init(
            id: role.stringId(),
            code: role.code,
            title: role.title,
            description: role.description,
            isDefault: role.isDefault
        )
    }
}

extension RoleDto: Content { }

extension RoleDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: .count(...50))
        validations.add("code", as: String.self, is: .count(...20))
        validations.add("description", as: String?.self, is: .count(...200) || .nil, required: false)
    }
}
