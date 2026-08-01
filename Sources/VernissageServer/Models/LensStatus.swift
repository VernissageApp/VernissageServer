//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Lens assigned to a status.
final class LensStatus: Model, @unchecked Sendable {
    static let schema: String = "LensStatuses"

    final class IDValue: Fields, Hashable, @unchecked Sendable {
        @Parent(key: "lensId")
        var lens: Lens

        @Parent(key: "statusId")
        var status: Status

        init() { }

        init(lensId: Int64, statusId: Int64) {
            self.$lens.id = lensId
            self.$status.id = statusId
        }

        static func == (lhs: IDValue, rhs: IDValue) -> Bool {
            lhs.$lens.id == rhs.$lens.id && lhs.$status.id == rhs.$status.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(self.$lens.id)
            hasher.combine(self.$status.id)
        }
    }

    @CompositeID()
    var id: IDValue?

    init() { }

    convenience init(lensId: Int64, statusId: Int64) {
        self.init()
        self.id = IDValue(lensId: lensId, statusId: statusId)
    }
}

/// Allows `LensStatus` to be encoded to and decoded from HTTP messages.
extension LensStatus: Content { }
