//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct UserUnmoveDto {
    let password: String
}

extension UserUnmoveDto: Content { }

extension UserUnmoveDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("password", as: String.self, is: !.empty && .count(...100), required: true)
    }
}
