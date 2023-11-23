//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum TrendingStatusPeriodDto: String {
    case daily
    case monthly
    case yearly
}

extension TrendingStatusPeriodDto {
    public func translate() -> TrendingStatusPeriod {
        switch self {
        case .daily:
            return TrendingStatusPeriod.daily
        case .monthly:
            return TrendingStatusPeriod.monthly
        case .yearly:
            return TrendingStatusPeriod.yearly
        }
    }
}

extension TrendingStatusPeriodDto: Content { }
