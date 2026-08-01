//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Film assigned to a status.
final class FilmStatus: Model, @unchecked Sendable {
    static let schema: String = "FilmStatuses"

    final class IDValue: Fields, Hashable, @unchecked Sendable {
        @Parent(key: "filmId")
        var film: Film

        @Parent(key: "statusId")
        var status: Status

        init() { }

        init(filmId: Int64, statusId: Int64) {
            self.$film.id = filmId
            self.$status.id = statusId
        }

        static func == (lhs: IDValue, rhs: IDValue) -> Bool {
            lhs.$film.id == rhs.$film.id && lhs.$status.id == rhs.$status.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(self.$film.id)
            hasher.combine(self.$status.id)
        }
    }

    @CompositeID()
    var id: IDValue?

    init() { }

    convenience init(filmId: Int64, statusId: Int64) {
        self.init()
        self.id = IDValue(filmId: filmId, statusId: statusId)
    }
}

/// Allows `FilmStatus` to be encoded to and decoded from HTTP messages.
extension FilmStatus: Content { }
