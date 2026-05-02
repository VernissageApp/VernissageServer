//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ActivityPubProfileUpdateJobDto {
    let userId: Int64
}

extension ActivityPubProfileUpdateJobDto: Content { }
