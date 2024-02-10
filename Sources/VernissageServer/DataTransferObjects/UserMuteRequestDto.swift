//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct UserMuteRequestDto {
    var muteStatuses: Bool
    var muteReblogs: Bool
    var muteNotifications: Bool
    var muteEnd: Date?
}

extension UserMuteRequestDto: Content { }
