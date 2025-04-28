//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct SharedBusinessCardDto {
    var id: String?
    var businessCardId: String?
    var businessCard: BusinessCardDto?
    var code: String?
    var title: String
    var note: String?
    var thirdPartyName: String?
    var thirdPartyEmail: String?
    var revokedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
    
    var messages: [SharedBusinessCardMessageDto]?
}

extension SharedBusinessCardDto {
    init(from sharedBusinessCard: SharedBusinessCard,
         messages: [SharedBusinessCardMessage]? = nil,
         businessCardDto: BusinessCardDto? = nil,
         baseAddress: String,
         baseImagesPath: String
    ) {
        self.init(id: sharedBusinessCard.stringId(),
                  businessCardId: businessCardDto?.id,
                  businessCard: businessCardDto,
                  code: sharedBusinessCard.code,
                  title: sharedBusinessCard.title,
                  note: sharedBusinessCard.note,
                  thirdPartyName: sharedBusinessCard.thirdPartyName,
                  thirdPartyEmail: sharedBusinessCard.thirdPartyEmail,
                  revokedAt: sharedBusinessCard.revokedAt,
                  createdAt: sharedBusinessCard.createdAt,
                  updatedAt: sharedBusinessCard.updatedAt,
                  messages: messages?.map { SharedBusinessCardMessageDto(from: $0, baseAddress: baseAddress, baseImagesPath: baseImagesPath) })
    }
}

extension SharedBusinessCardDto: Content { }

extension SharedBusinessCardDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("code", as: String?.self, is: .count(...64) || .nil, required: false)
        validations.add("title", as: String.self, is: .count(1...200), required: true)
        validations.add("note", as: String?.self, is: .count(...500) || .nil, required: false)
        validations.add("thirdPartyName", as: String?.self, is: .count(...100) || .nil, required: false)
        validations.add("thirdPartyEmail", as: String?.self, is: .email || .nil, required: false)
    }
}
