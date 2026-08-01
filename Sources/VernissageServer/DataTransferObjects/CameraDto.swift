//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct CameraDto {
    var id: String?
    var name: String
    var make: String?
    var model: String?
    var amount: Int
}

extension CameraDto {
    init(from camera: Camera) {
        self.init(
            id: camera.stringId(),
            name: camera.name,
            make: camera.make,
            model: camera.model,
            amount: camera.amount
        )
    }
}

extension CameraDto: Content { }
