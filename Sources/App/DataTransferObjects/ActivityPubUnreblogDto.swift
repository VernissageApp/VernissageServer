//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

final class ActivityPubUnreblogDto {
    let reblogId: Int64
    let activityPubReblogId: String
    let mainId: Int64
    
    init(reblogId: Int64, activityPubReblogId: String, mainId: Int64) {
        self.reblogId = reblogId
        self.activityPubReblogId = activityPubReblogId
        self.mainId = mainId
    }
}

extension ActivityPubUnreblogDto: Content { }
