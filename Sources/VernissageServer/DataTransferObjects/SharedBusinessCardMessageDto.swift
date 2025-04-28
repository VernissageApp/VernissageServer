//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct SharedBusinessCardMessageDto {
    var id: String?
    var addedByUser: Bool?
    var message: String
    var createdAt: Date?
    var updatedAt: Date?
}

extension SharedBusinessCardMessageDto {
    init(from sharedBusinessCardMessage: SharedBusinessCardMessage, baseAddress: String, baseImagesPath: String) {
        var addedByUser = false
        if sharedBusinessCardMessage.$user.id != nil {
            addedByUser = true
        }
        
        self.init(id: sharedBusinessCardMessage.stringId(),
                  addedByUser: addedByUser,
                  message: sharedBusinessCardMessage.message,
                  createdAt: sharedBusinessCardMessage.createdAt,
                  updatedAt: sharedBusinessCardMessage.updatedAt)
    }
}

extension SharedBusinessCardMessageDto: Content { }

extension SharedBusinessCardMessageDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("message", as: String.self, is: .count(1...500), required: true)
    }
}
