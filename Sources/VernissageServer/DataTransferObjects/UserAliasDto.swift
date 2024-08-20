//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct UserAliasDto {
    var id: String?
    var alias: String
}

extension UserAliasDto: Content { }

extension UserAliasDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("alias", as: String.self, is: !.empty && .count(...100), required: true)
    }
}
