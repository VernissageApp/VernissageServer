//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

final class ActivityPubFollowRespondDto {
    let approved: Bool
    let requesting: String
    let asked: String
    let sharedInbox: URL
    let id: Int64
    let orginalRequestId: String
    let privateKey: String
    
    init(approved: Bool, requesting: String, asked: String, sharedInbox: URL, id: Int64, orginalRequestId: String, privateKey: String) {
        self.approved = approved
        self.requesting = requesting
        self.asked = asked
        self.sharedInbox = sharedInbox
        self.id = id
        self.orginalRequestId = orginalRequestId
        self.privateKey = privateKey
    }
}

extension ActivityPubFollowRespondDto: Content { }
