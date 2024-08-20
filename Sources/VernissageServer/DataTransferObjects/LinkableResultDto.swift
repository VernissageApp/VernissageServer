//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LinkableResultDto<T> where T: Content {
    var maxId: String?
    var minId: String?
    var data: [T]
}

extension LinkableResultDto {
    init(basedOn linkable: LinkableResult<T>) {
        self.init(maxId: linkable.maxId,
                  minId: linkable.minId,
                  data: linkable.data)
    }
}

extension LinkableResultDto: Content { }
