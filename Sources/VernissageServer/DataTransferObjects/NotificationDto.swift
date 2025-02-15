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
    var mainStatus: StatusDto?
    var createdAt: String?
}

extension NotificationDto {
    init(id: String?, notificationType: NotificationTypeDto, byUser: UserDto, status: StatusDto?, mainStatus: StatusDto?, createdAt: Date?) {
        self.id = id
        self.notificationType = notificationType
        self.byUser = byUser
        self.status = status
        self.mainStatus = mainStatus
        self.createdAt = createdAt?.toISO8601String()
    }
}

extension NotificationDto: Content { }
