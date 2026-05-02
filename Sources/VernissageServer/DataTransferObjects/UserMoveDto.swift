//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct UserMoveDto {
    let account: String
    let password: String
}

extension UserMoveDto: Content { }

extension UserMoveDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("account", as: String.self, is: !.empty && .count(...300), required: true)
        validations.add("password", as: String.self, is: !.empty && .count(...100), required: true)
    }
}
