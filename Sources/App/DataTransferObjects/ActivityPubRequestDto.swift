//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

final class ActivityPubRequestDto {
    let activity: ActivityDto
    let headers: [String: String]
    let bodyHash: String?
    let httpMethod: ActivityPubRequestMethod
    let httpPath: ActivityPubRequestPath
    
    init(activity: ActivityDto, headers: [String: String], bodyHash: String?, httpMethod: ActivityPubRequestMethod, httpPath: ActivityPubRequestPath) {
        self.activity = activity
        self.headers = headers
        self.bodyHash = bodyHash
        self.httpMethod = httpMethod
        self.httpPath = httpPath
    }
}

extension ActivityPubRequestDto: Content { }