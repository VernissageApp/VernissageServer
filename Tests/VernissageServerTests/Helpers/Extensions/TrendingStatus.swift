//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Application {
    func createTrendingStatus(trendingPeriod: TrendingPeriod, statusId: Int64) async throws {
        let id = await ApplicationManager.shared.generateId()
        let trendingStatus = TrendingStatus(id: id, trendingPeriod: trendingPeriod, statusId: statusId, amount: 1)
        _ = try await trendingStatus.save(on: self.db)
    }
}
