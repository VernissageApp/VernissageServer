//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

struct ActivityPubRequestDto {
    let activity: ActivityDto
    let headers: [String: String]
    let bodyHash: String?
}

extension ActivityPubRequestDto: Content { }
