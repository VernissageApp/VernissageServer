//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LicenseDto {
    var id: String?
    var name: String
    var code: String
    var description: String?
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
