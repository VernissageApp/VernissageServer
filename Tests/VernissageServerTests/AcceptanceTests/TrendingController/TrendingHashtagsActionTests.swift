//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class TrendingHashtagsActionTests: CustomTestCase {
    
    func testTrendingHashtagsShouldBeReturnedForUnauthorizedUser() async throws {
        
        // Arrange.
        try await Setting.update(key: .showTrendingForAnonymous, value: .boolean(true))

        _ = try await User.create(userName: "gregrobins")
        try await TrendingHashtag.create(trendingPeriod: .daily, hashtag: "blackandwhite")
        try await TrendingHashtag.create(trendingPeriod: .daily, hashtag: "street")
        try await TrendingHashtag.create(trendingPeriod: .daily, hashtag: "photos")
        try await TrendingHashtag.create(trendingPeriod: .monthly, hashtag: "wedding")
        
        // Act.
        let hashtagsFromApi = try SharedApplication.application().getResponse(
            to: "/trending/hashtags?limit=2&period=daily",
            method: .GET,
            decodeTo: LinkableResultDto<HashtagDto>.self
        )
        
        // Assert.
        // Assert.
        XCTAssert(hashtagsFromApi.data.count == 2, "Hashtags list should be returned.")
        XCTAssertEqual(hashtagsFromApi.data[0].name, "photos", "First hashtag is not visible.")
        XCTAssertEqual(hashtagsFromApi.data[1].name, "street", "Second hashtag is not visible.")
    }
    
    func testTrendingHashtagsShouldNotBeReturnedForUnauthorizedUserWhenPublicAccessIsDisabled() async throws {
        // Arrange.
        try await Setting.update(key: .showTrendingForAnonymous, value: .boolean(false))
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/trending/hashtags?limit=2&period=daily",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
