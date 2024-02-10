//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ReportRequestDto {
    var reportedUserId: String
    var statusId: String?
    var comment: String?
    var forward: Bool
    var category: String?
    var ruleIds: [Int]?
}

extension ReportRequestDto: Content { }

extension ReportRequestDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("comment", as: String?.self, is: .count(...1000) || .nil, required: false)
        validations.add("category", as: String?.self, is: .count(...100) || .nil, required: false)
    }
}
