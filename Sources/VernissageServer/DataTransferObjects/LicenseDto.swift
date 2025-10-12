//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LicenseDto {
    var id: String?
    var name: String
    var code: String
    var description: String
    var url: String?
}

extension LicenseDto {
    init(from license: License) {
        self.init(id: license.stringId(),
                  name: license.name,
                  code: license.code,
                  description: license.description,
                  url: license.url)
    }
}

extension LicenseDto: Content { }

extension LicenseDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty && .count(...100), required: true)
        validations.add("code", as: String.self, is: .count(...50), required: true)
        validations.add("description", as: String.self, is: .count(...1000), required: true)
        validations.add("url", as: String?.self, is: .count(...500) || .nil, required: false)
    }
}
