//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct EmailDto: Sendable {
    var to: EmailAddressDto
    var subject: String
    var body: String
    var from: EmailAddressDto?
    var replyTo: EmailAddressDto?
}

extension EmailDto: Content { }
