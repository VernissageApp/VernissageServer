//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct StatusDeleteJobDto {
    var userId: Int64
    var statusId: Int64
    var activityPubStatusId: String
}

extension StatusDeleteJobDto: Content { }
