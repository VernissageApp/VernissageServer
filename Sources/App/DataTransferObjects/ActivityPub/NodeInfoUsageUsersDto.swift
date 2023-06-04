//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct NodeInfoUsageUsersDto {
    public let total: Int
    public let activeMonth: Int
    public let activeHalfyear: Int
}

extension NodeInfoUsageUsersDto: Content { }
