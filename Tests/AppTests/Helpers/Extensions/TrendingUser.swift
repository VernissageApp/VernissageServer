//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTVapor
import Fluent

extension TrendingUser {
    static func create(trendingPeriod: TrendingPeriod, userId: Int64) async throws {
        let trendingUser = TrendingUser(trendingPeriod: trendingPeriod, userId: userId)
        _ = try await trendingUser.save(on: SharedApplication.application().db)
    }
}
