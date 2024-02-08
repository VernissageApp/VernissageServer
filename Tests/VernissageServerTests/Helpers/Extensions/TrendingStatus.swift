//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTVapor
import Fluent

extension TrendingStatus {
    static func create(trendingPeriod: TrendingPeriod, statusId: Int64) async throws {
        let trendingStatus = TrendingStatus(trendingPeriod: trendingPeriod, statusId: statusId)
        _ = try await trendingStatus.save(on: SharedApplication.application().db)
    }
}
