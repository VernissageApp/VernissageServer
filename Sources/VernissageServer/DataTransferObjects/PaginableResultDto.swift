//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import FluentKit

struct PaginableResultDto<T> where T: Content {
    let data: [T]
    let page: Int
    let size: Int
    let total: Int
}

extension PaginableResultDto {
    init(basedOn page: Page<T>) {
        self.init(data: page.items, page: page.metadata.page, size: page.metadata.per, total: page.metadata.total)
    }
}

extension PaginableResultDto: Content { }
