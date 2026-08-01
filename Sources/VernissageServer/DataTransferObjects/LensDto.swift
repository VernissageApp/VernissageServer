//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LensDto {
    var id: String?
    var name: String
    var amount: Int
}

extension LensDto {
    init(from lens: Lens) {
        self.init(
            id: lens.stringId(),
            name: lens.name,
            amount: lens.amount
        )
    }
}

extension LensDto: Content { }
