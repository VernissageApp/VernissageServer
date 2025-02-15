//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension Date {
    func toISO8601String() -> String {
        return CustomFormatter().iso8601withFractionalSeconds().string(from: self)
    }
}

public extension String {
    func fromISO8601String() -> Date? {
        return  CustomFormatter().iso8601withFractionalSeconds().date(from: self)
    }
}
