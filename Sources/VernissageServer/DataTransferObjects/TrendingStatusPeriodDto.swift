//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum TrendingStatusPeriodDto: String {
    case daily
    case monthly
    case yearly
}

extension TrendingStatusPeriodDto {
    public func translate() -> TrendingPeriod {
        switch self {
        case .daily:
            return TrendingPeriod.daily
        case .monthly:
            return TrendingPeriod.monthly
        case .yearly:
            return TrendingPeriod.yearly
        }
    }
}

extension TrendingStatusPeriodDto: Content { }
