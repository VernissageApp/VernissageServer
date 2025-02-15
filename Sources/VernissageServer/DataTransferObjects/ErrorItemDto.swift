//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ErrorItemDto {
    var id: String?
    var source: ErrorItemSourceDto
    var code: String
    var message: String
    var exception: String?
    var userAgent: String?
    var clientVersion: String?
    var serverVersion: String?
    var createdAt: Date?
}

extension ErrorItemDto {
    init(from errorItem: ErrorItem) {
        self.init(id: errorItem.stringId(),
                  source: ErrorItemSourceDto.from(errorItem.source),
                  code: errorItem.code,
                  message: errorItem.message,
                  exception: errorItem.exception,
                  userAgent: errorItem.userAgent,
                  clientVersion: errorItem.clientVersion,
                  serverVersion: errorItem.serverVersion,
                  createdAt: errorItem.createdAt)
    }
}

extension ErrorItemDto: Content { }

extension ErrorItemDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("code", as: String.self, is: .count(1...10) && .alphanumeric)
        validations.add("clientVersion", as: String?.self, is: .nil || .count(1...50), required: false)
        validations.add("serverVersion", as: String?.self, is: .nil || .count(1...50), required: false)
        validations.add("message", as: String.self, is: !.empty)
    }
}

