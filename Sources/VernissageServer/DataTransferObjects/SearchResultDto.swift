//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct SearchResultDto {
    let users: [UserDto]?
    let statuses: [UserDto]?
    let hashtags: [UserDto]?
    
    init(users: [UserDto]? = nil, statuses: [UserDto]? = nil, hashtags: [UserDto]? = nil) {
        self.users = users
        self.statuses = statuses
        self.hashtags = hashtags
    }
}

extension SearchResultDto: Content { }
