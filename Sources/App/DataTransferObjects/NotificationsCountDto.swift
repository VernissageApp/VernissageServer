//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct NotificationsCountDto {
    var amount: Int = 0
    var notificationId: String?
}

extension NotificationsCountDto: Content { }
