//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ArticlesCountDto {
    var amount: Int = 0
    var articleId: String?
}

extension ArticlesCountDto: Content { }
