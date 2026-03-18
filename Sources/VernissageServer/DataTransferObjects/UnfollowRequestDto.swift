//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct UnfollowRequestDto {
    var removeStatusesFromTimeline: Bool?
    var removeReblogsFromTimeline: Bool?
}

extension UnfollowRequestDto: Content { }
