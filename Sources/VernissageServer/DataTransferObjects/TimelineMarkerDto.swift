//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Timeline marker exposed by the API.
struct TimelineMarkerDto {
    var statusId: String
}

extension TimelineMarkerDto: Content { }
