//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct HomeCardDto {
    var id: String?
    var title: String
    var body: String
    var order: Int
}

extension HomeCardDto {
    init(from homeCard: HomeCard) {
        self.init(id: homeCard.stringId(),
                  title: homeCard.title,
                  body: homeCard.body,
                  order: homeCard.order)
    }
}

extension HomeCardDto: Content { }

extension HomeCardDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: !.empty && .count(...200), required: true)
        validations.add("body", as: String.self, is: !.empty && .count(...1000), required: true)
    }
}
