//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum TrendingStatusPeriod: Int, Codable {
    case daily = 1
    case monthly = 2
    case yearly = 3
    
    func getDate() -> Date {
        switch self {
        case .daily:
            return Date.yesterday
        case .monthly:
            return Date.monthAgo
        case .yearly:
            return Date.yearAgo
        }
    }
}
