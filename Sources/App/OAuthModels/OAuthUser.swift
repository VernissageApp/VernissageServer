//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct OAuthUser {
    let uniqueId: String
    let email: String
    let familyName: String?
    let givenName: String?
    let name: String?
}
