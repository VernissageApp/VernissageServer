//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct NodeInfoUsageDto {
    public let users: NodeInfoUsageUsersDto
    public let localPosts: Int
    public let localComments: Int
}

extension NodeInfoUsageDto: Content { }
