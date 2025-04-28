//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct BusinessCardDto {
    var id: String?
    var user: UserDto?
    var title: String
    var subtitle: String?
    var body: String?
    var website: String?
    var telephone: String?
    var email: String?
    var color1: String
    var color2: String
    var color3: String
    var createdAt: Date?
    var updatedAt: Date?
    var fields: [BusinessCardFieldDto]?
}

extension BusinessCardDto {
    init(from businessCard: BusinessCard, baseAddress: String, baseImagesPath: String) {
        self.init(id: businessCard.stringId(),
                  user: UserDto(from: businessCard.user, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
                  title: businessCard.title,
                  subtitle: businessCard.subtitle,
                  body: businessCard.body,
                  website: businessCard.website,
                  telephone: businessCard.telephone,
                  email: businessCard.email,
                  color1: businessCard.color1,
                  color2: businessCard.color2,
                  color3: businessCard.color3,
                  createdAt: businessCard.createdAt,
                  updatedAt: businessCard.updatedAt,
                  fields: businessCard.businessCardFields.map { BusinessCardFieldDto(from: $0) })
    }
}

extension BusinessCardDto: Content { }

extension BusinessCardDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: .count(1...200), required: true)
        validations.add("subtitle", as: String?.self, is: .count(...500) || .nil, required: false)
        validations.add("website", as: String?.self, is: .count(...500) || .nil, required: false)
        validations.add("telephone", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("email", as: String?.self, is: .count(...500) || .nil, required: false)
        validations.add("color1", as: String.self, is: .count(1...50), required: true)
        validations.add("color2", as: String.self, is: .count(1...50), required: true)
        validations.add("color3", as: String.self, is: .count(1...50), required: true)
    }
}
