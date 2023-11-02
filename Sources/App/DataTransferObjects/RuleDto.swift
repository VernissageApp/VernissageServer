//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct RuleDto {
    var id: String?
    var order: Int
    var text: String
}

extension RuleDto {
    init(from rule: Rule) {
        self.init(id: rule.stringId(), order: rule.order, text: rule.text)
    }
}

extension RuleDto: Content { }
