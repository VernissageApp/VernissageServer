//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Trending (GET /trending/hashtags)", .serialized, .tags(.trending))
    struct TrendingHashtagsActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Trending hashtags should be returned for unauthorized user when public access is enabled")
        func trendingHashtagsShouldBeReturnedForUnauthorizedUserWhenPublicAccessIsEnabled() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showTrendingForAnonymous, value: .boolean(true))
            
            _ = try await application.createUser(userName: "gregrobins")
            try await application.createTrendingHashtag(trendingPeriod: .daily, hashtag: "blackandwhite")
            try await application.createTrendingHashtag(trendingPeriod: .daily, hashtag: "street")
            try await application.createTrendingHashtag(trendingPeriod: .daily, hashtag: "photos")
            try await application.createTrendingHashtag(trendingPeriod: .monthly, hashtag: "wedding")
            
            // Act.
            let hashtagsFromApi = try await application.getResponse(
                to: "/trending/hashtags?limit=2&period=daily",
                method: .GET,
                decodeTo: LinkableResultDto<HashtagDto>.self
            )
            
            // Assert.
            #expect(hashtagsFromApi.data.count == 2, "Hashtags list should be returned.")
            #expect(hashtagsFromApi.data[0].name == "photos", "First hashtag is not visible.")
            #expect(hashtagsFromApi.data[1].name == "street", "Second hashtag is not visible.")
        }
        
        @Test("Trending hashtags should not be returned for unauthorized user when public access is disabled")
        func trendingHashtagsShouldNotBeReturnedForUnauthorizedUserWhenPublicAccessIsDisabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .showTrendingForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try await application.sendRequest(
                to: "/trending/hashtags?limit=2&period=daily",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
