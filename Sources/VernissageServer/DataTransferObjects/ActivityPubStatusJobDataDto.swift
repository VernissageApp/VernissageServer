//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

struct ActivityPubStatusJobDataDto {
    let statusActivityPubEventId: Int64
    let activityPubReblog: ActivityPubReblogDto?
    let activityPubUnreblog: ActivityPubUnreblogDto?
    let statusFavouriteId: String?
    
    init(statusActivityPubEventId: Int64,
         activityPubReblog: ActivityPubReblogDto? = nil,
         activityPubUnreblog: ActivityPubUnreblogDto? = nil,
         statusFavouriteId: String? = nil
    ) {
        self.statusActivityPubEventId = statusActivityPubEventId
        self.activityPubReblog = activityPubReblog
        self.activityPubUnreblog = activityPubUnreblog
        self.statusFavouriteId = statusFavouriteId
    }
}

extension ActivityPubStatusJobDataDto: Content { }
