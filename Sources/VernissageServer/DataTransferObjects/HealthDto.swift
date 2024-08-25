//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct HealthDto {
    var isDatabaseHealthy: Bool
    var isQueueHealthy: Bool
    var isWebPushHealthy: Bool
    var isStorageHealthy: Bool
}

extension HealthDto: Content { }
