//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct FilmDto {
    var id: String?
    var name: String
    var amount: Int
}

extension FilmDto {
    init(from film: Film) {
        self.init(
            id: film.stringId(),
            name: film.name,
            amount: film.amount
        )
    }
}

extension FilmDto: Content { }
