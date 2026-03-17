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

extension ActivityPubStatusJobDataDto {
    public func encode() throws -> String? {
        let eventContextData = try JSONEncoder().encode(self)
        let eventContextString = String(data: eventContextData, encoding: .utf8)
        
        return eventContextString
    }
    
    public init?(from eventContextString: String) throws {
        guard let eventContextData = eventContextString.data(using: .utf8) else {
            return nil
        }
        
        let eventContext = try JSONDecoder().decode(ActivityPubStatusJobDataDto.self, from: eventContextData)
        self.init(statusActivityPubEventId: eventContext.statusActivityPubEventId,
                  activityPubReblog: eventContext.activityPubReblog,
                  activityPubUnreblog: eventContext.activityPubUnreblog,
                  statusFavouriteId: eventContext.statusFavouriteId)
    }
}
