//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct NotificationDto {
    var id: String?
    var notificationType: NotificationTypeDto
    var byUser: UserDto
    var status: StatusDto?
}

extension NotificationDto: Content { }
