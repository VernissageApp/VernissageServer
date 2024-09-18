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

extension TrendingControllerTests {
    
    @Suite("GET /users", .serialized, .tags(.trending))
    struct TrendingUsersActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Trending users should be returned for unauthorized user when public access is enabled")
        func trendingUsersShouldBeReturnedForUnauthorizedUserWhenPublicAccessIsEnabled() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showTrendingForAnonymous, value: .boolean(true))
            
            let user1 = try await application.createUser(userName: "fredtoby")
            let user2 = try await application.createUser(userName: "martintoby")
            let user3 = try await application.createUser(userName: "tinatoby")
            let user4 = try await application.createUser(userName: "gintoby")
            let user5 = try await application.createUser(userName: "tedtoby")
            
            try await application.createTrendingUser(trendingPeriod: .daily, userId: user1.id!)
            try await application.createTrendingUser(trendingPeriod: .daily, userId: user2.id!)
            try await application.createTrendingUser(trendingPeriod: .daily, userId: user3.id!)
            try await application.createTrendingUser(trendingPeriod: .daily, userId: user4.id!)
            try await application.createTrendingUser(trendingPeriod: .monthly, userId: user5.id!)
            
            // Act.
            let usersFromApi = try application.getResponse(
                to: "/trending/users?limit=2&period=daily",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(usersFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(usersFromApi.data[0].userName == "gintoby", "First user is not visible.")
            #expect(usersFromApi.data[1].userName == "tinatoby", "Second user is not visible.")
        }
        
        @Test("Trending users should not be returned for unauthorized user when public access is disabled")
        func trendingUsersShouldNotBeReturnedForUnauthorizedUserWhenPublicAccessIsDisabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .showTrendingForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try application.sendRequest(
                to: "/trending/users?limit=2&period=daily",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
