//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LinkableResult<T> where T: Content {
    var maxId: String?
    var minId: String?
    var data: [T]
}

extension LinkableResult: Content { }
