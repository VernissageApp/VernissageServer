//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct StatusUnfavouriteJobDto {
    var statusFavouriteId: String
    var userId: Int64
    var statusId: Int64
}

extension StatusUnfavouriteJobDto: Content { }
