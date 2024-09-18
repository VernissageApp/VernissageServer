//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension JSONEncoder.DateEncodingStrategy {
    static let customISO8601 = custom {
        var container = $1.singleValueContainer()
        try container.encode(CustomFormatter().iso8601withFractionalSeconds().string(from: $0))
    }
}
