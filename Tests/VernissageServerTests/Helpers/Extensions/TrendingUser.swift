//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Application {
    func createTrendingUser(trendingPeriod: TrendingPeriod, userId: Int64) async throws {
        let id = await ApplicationManager.shared.generateId()
        let trendingUser = TrendingUser(id: id, trendingPeriod: trendingPeriod, userId: userId, amount: 1)
        _ = try await trendingUser.save(on: self.db)
    }
}
