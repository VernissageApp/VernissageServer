//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

final class ActivityPubUnreblogDto {
    let activityPubStatusId: String
    let activityPubProfile: String
    let published: Date
    let activityPubReblogProfile: String
    let activityPubReblogStatusId: String
    
    let statusId: Int64
    let userId: Int64
    let orginalStatusId: Int64
    
    init(activityPubStatusId: String,
         activityPubProfile: String,
         published: Date,
         activityPubReblogProfile: String,
         activityPubReblogStatusId: String,
         statusId: Int64,
         userId: Int64,
         orginalStatusId: Int64
    ) {
        self.activityPubStatusId = activityPubStatusId
        self.activityPubProfile = activityPubProfile
        self.published = published
        self.activityPubReblogProfile = activityPubReblogProfile
        self.activityPubReblogStatusId = activityPubReblogStatusId
        
        self.statusId = statusId
        self.userId = userId
        self.orginalStatusId = orginalStatusId
    }
}

extension ActivityPubUnreblogDto: Content { }
