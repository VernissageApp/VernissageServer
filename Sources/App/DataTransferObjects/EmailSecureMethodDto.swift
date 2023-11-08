//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum EmailSecureMethodDto: String {
    case none
    case ssl
    case startTls
    case startTlsWhenAvailable
}

extension EmailSecureMethodDto: Content { }
