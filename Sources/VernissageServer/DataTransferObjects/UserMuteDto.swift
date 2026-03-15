//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct UserMuteDto {
    var id: String?
    var mutedUser: UserDto
    var muteStatuses: Bool
    var muteReblogs: Bool
    var muteNotifications: Bool
    var muteEnd: Date?
    var createdAt: Date?
    var updatedAt: Date?
}

extension UserMuteDto {
    init(from userMute: UserMute, baseImagesPath: String, baseAddress: String) {
        self.init(id: userMute.stringId(),
                  mutedUser: UserDto(from: userMute.mutedUser, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
                  muteStatuses: userMute.muteStatuses,
                  muteReblogs: userMute.muteReblogs,
                  muteNotifications: userMute.muteNotifications,
                  muteEnd: userMute.muteEnd,
                  createdAt: userMute.createdAt,
                  updatedAt: userMute.updatedAt)
    }
}

extension UserMuteDto: Content { }
