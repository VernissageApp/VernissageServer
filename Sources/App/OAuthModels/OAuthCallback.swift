//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct OAuthCallback: Content {
    var code: String?
    var state: String?
    var scope: String?
    var authuser: String?
    var prompt: String?
}
