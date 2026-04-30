//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

struct ActivityPubRequestDto: Sendable {
    let activity: ActivityDto
    let headers: [String: String]
    let bodyHash: String?
    let bodyValue: String
    let httpMethod: ActivityPubRequestMethod
    let httpPath: ActivityPubRequestPath
    let receivedAt: Date?
    
    init(activity: ActivityDto,
         headers: [String: String],
         bodyHash: String?,
         bodyValue: String,
         httpMethod: ActivityPubRequestMethod,
         httpPath: ActivityPubRequestPath,
         receivedAt: Date? = nil) {
        self.activity = activity
        self.headers = headers
        self.bodyHash = bodyHash
        self.bodyValue = bodyValue
        self.httpMethod = httpMethod
        self.httpPath = httpPath
        self.receivedAt = receivedAt
    }
}

extension ActivityPubRequestDto: Content { }
