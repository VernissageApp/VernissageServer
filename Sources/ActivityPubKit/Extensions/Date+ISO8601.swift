//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//


import Foundation

public extension Date {
    func toISO8601String() -> String {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.string(from: self)
    }
}

public extension String {
    func fromISO8601String() -> Date? {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.date(from: self)
    }
}
