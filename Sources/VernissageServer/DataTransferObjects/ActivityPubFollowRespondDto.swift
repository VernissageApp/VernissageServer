//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

struct ActivityPubFollowRespondDto {
    let approved: Bool
    let requesting: String
    let asked: String
    let inbox: URL
    let id: Int64
    let orginalRequestId: String
    let privateKey: String
    
    init(approved: Bool, requesting: String, asked: String, inbox: URL, id: Int64, orginalRequestId: String, privateKey: String) {
        self.approved = approved
        self.requesting = requesting
        self.asked = asked
        self.inbox = inbox
        self.id = id
        self.orginalRequestId = orginalRequestId
        self.privateKey = privateKey
    }
}

extension ActivityPubFollowRespondDto: Content { }
