//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct NodeInfoUsageDto {
    public let users: NodeInfoUsageUsersDto
    public let localPosts: Int
    public let localComments: Int
    
    public init(users: NodeInfoUsageUsersDto, localPosts: Int, localComments: Int) {
        self.users = users
        self.localPosts = localPosts
        self.localComments = localComments
    }
}

extension NodeInfoUsageDto: Codable { }
