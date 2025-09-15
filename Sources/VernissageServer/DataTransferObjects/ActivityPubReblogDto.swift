//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

struct ActivityPubReblogDto {
    let activityPubStatusId: String
    let activityPubProfile: String
    let published: Date
    let activityPubReblogProfile: String
    let activityPubReblogStatusId: String
        
    init(activityPubStatusId: String,
         activityPubProfile: String,
         published: Date,
         activityPubReblogProfile: String,
         activityPubReblogStatusId: String
    ) {
        self.activityPubStatusId = activityPubStatusId
        self.activityPubProfile = activityPubProfile
        self.published = published
        self.activityPubReblogProfile = activityPubReblogProfile
        self.activityPubReblogStatusId = activityPubReblogStatusId
    }
}

extension ActivityPubReblogDto: Content { }
