//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class TrendingUsersActionTests: CustomTestCase {
    
    func testTrendingUsersShouldBeReturnedForUnauthorizedUser() async throws {
        
        // Arrange.
        try await Setting.update(key: .showTrendingForAnonymous, value: .boolean(true))

        let user1 = try await User.create(userName: "fredtoby")
        let user2 = try await User.create(userName: "martintoby")
        let user3 = try await User.create(userName: "tinatoby")
        let user4 = try await User.create(userName: "gintoby")
        let user5 = try await User.create(userName: "tedtoby")

        try await TrendingUser.create(trendingPeriod: .daily, userId: user1.id!)
        try await TrendingUser.create(trendingPeriod: .daily, userId: user2.id!)
        try await TrendingUser.create(trendingPeriod: .daily, userId: user3.id!)
        try await TrendingUser.create(trendingPeriod: .daily, userId: user4.id!)
        try await TrendingUser.create(trendingPeriod: .monthly, userId: user5.id!)
        
        // Act.
        let usersFromApi = try SharedApplication.application().getResponse(
            to: "/trending/users?limit=2&period=daily",
            method: .GET,
            decodeTo: LinkableResultDto<UserDto>.self
        )
        
        // Assert.
        // Assert.
        XCTAssert(usersFromApi.data.count == 2, "Statuses list should be returned.")
        XCTAssertEqual(usersFromApi.data[0].userName, "gintoby", "First user is not visible.")
        XCTAssertEqual(usersFromApi.data[1].userName, "tinatoby", "Second user is not visible.")
    }
    
    func testTrendingUsersShouldNotBeReturnedForUnauthorizedUserWhenPublicAssessIdDisabled() async throws {
        // Arrange.
        try await Setting.update(key: .showTrendingForAnonymous, value: .boolean(false))
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/trending/users?limit=2&period=daily",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
