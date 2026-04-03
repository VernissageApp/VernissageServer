//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct UserBlockedUserDto {
    var id: String?
    var blockedUser: UserDto
    var reason: String?
    var createdAt: Date?
    var updatedAt: Date?
}

extension UserBlockedUserDto {
    init(from userBlockedUser: UserBlockedUser, baseImagesPath: String, baseAddress: String) {
        self.init(id: userBlockedUser.stringId(),
                  blockedUser: UserDto(from: userBlockedUser.blockedUser, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
                  reason: userBlockedUser.reason,
                  createdAt: userBlockedUser.createdAt,
                  updatedAt: userBlockedUser.updatedAt)
    }
}

extension UserBlockedUserDto: Content { }
