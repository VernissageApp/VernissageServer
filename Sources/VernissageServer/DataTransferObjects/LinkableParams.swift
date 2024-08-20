//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LinkableParams {
    let maxId: String?
    let minId: String?
    let sinceId: String?
    let limit: Int
}
