//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct SearchResultDto {
    let users: [UserDto]?
    let statuses: [StatusDto]?
    let hashtags: [HashtagDto]?
    
    init(users: [UserDto]? = nil, statuses: [StatusDto]? = nil, hashtags: [HashtagDto]? = nil) {
        self.users = users
        self.statuses = statuses
        self.hashtags = hashtags
    }
}

extension SearchResultDto: Content { }
