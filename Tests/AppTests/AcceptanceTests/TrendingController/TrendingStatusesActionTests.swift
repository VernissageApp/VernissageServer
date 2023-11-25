//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class TrendingStatusesActionTests: CustomTestCase {
    
    func testTrendingStatusesShouldBeReturnedForUnauthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "greggobels")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Public note", amount: 4)
        _ = try await UserStatus.create(type: .owner, user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        try await TrendingStatus.create(trendingPeriod: .daily, statusId: statuses[0].id!)
        try await TrendingStatus.create(trendingPeriod: .daily, statusId: statuses[1].id!)
        try await TrendingStatus.create(trendingPeriod: .daily, statusId: statuses[2].id!)
        try await TrendingStatus.create(trendingPeriod: .monthly, statusId: statuses[3].id!)
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/trending/statuses?limit=2&period=daily",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        // Assert.
        XCTAssert(statusesFromApi.data.count == 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Public note 3", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Public note 2", "Second status is not visible.")
    }
}
