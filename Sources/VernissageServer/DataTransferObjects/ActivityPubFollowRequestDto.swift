//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

struct ActivityPubFollowRequestDto {
    public enum FollowRequestType: String {
        case follow
        case unfollow
    }
    
    let type: FollowRequestType
    let source: String
    let target: String
    let sharedInbox: URL
    let id: Int64
    let privateKey: String
    
    init(type: FollowRequestType, source: String, target: String, sharedInbox: URL, id: Int64, privateKey: String) {
        self.type = type
        self.source = source
        self.target = target
        self.sharedInbox = sharedInbox
        self.id = id
        self.privateKey = privateKey
    }
}

extension ActivityPubFollowRequestDto.FollowRequestType: Content { }
extension ActivityPubFollowRequestDto: Content { }
