//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Camera assigned to a status.
final class CameraStatus: Model, @unchecked Sendable {
    static let schema: String = "CameraStatuses"

    final class IDValue: Fields, Hashable, @unchecked Sendable {
        @Parent(key: "cameraId")
        var camera: Camera

        @Parent(key: "statusId")
        var status: Status

        init() { }

        init(cameraId: Int64, statusId: Int64) {
            self.$camera.id = cameraId
            self.$status.id = statusId
        }

        static func == (lhs: IDValue, rhs: IDValue) -> Bool {
            lhs.$camera.id == rhs.$camera.id && lhs.$status.id == rhs.$status.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(self.$camera.id)
            hasher.combine(self.$status.id)
        }
    }

    @CompositeID()
    var id: IDValue?

    init() { }

    convenience init(cameraId: Int64, statusId: Int64) {
        self.init()
        self.id = IDValue(cameraId: cameraId, statusId: statusId)
    }
}

/// Allows `CameraStatus` to be encoded to and decoded from HTTP messages.
extension CameraStatus: Content { }
