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
    
    @Suite("Trending (GET /trending/users)", .serialized, .tags(.trending))
    struct TrendingUsersActionTests {
        enum HiddenRelationship: String, CaseIterable {
            case muted
            case blocked
        }

        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Trending users should be returned for unauthorized user when public access is enabled`() async throws {
            
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
            let usersFromApi = try await application.getResponse(
                to: "/trending/users?limit=2&period=daily",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(usersFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(usersFromApi.data[0].userName == "gintoby", "First user is not visible.")
            #expect(usersFromApi.data[1].userName == "tinatoby", "Second user is not visible.")
        }
        
        @Test
        func `Trending users should not be returned when user is deleted`() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showTrendingForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "deletedtrendinguser")
            try await application.createTrendingUser(trendingPeriod: .daily, userId: try #require(user.id))
            try await user.delete(on: application.db)
            
            // Act.
            let usersFromApi = try await application.getResponse(
                to: "/trending/users?limit=2&period=daily",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(usersFromApi.data.contains(where: { $0.id == user.stringId() }) == false, "Deleted users should not be returned.")
        }

        @Test(arguments: HiddenRelationship.allCases)
        func `Hidden accounts should not be returned as trending users for authorized user`(
            relationship: HiddenRelationship
        ) async throws {
            // Arrange.
            let suffix = relationship.rawValue
            let viewer = try await application.createUser(userName: "trendinguserviewer\(suffix)")
            let visibleUser = try await application.createUser(userName: "trendinguservisible\(suffix)")
            let hiddenUser = try await application.createUser(userName: "trendinguserhidden\(suffix)")

            try await application.createTrendingUser(trendingPeriod: .daily, userId: try visibleUser.requireID())
            try await application.createTrendingUser(trendingPeriod: .daily, userId: try hiddenUser.requireID())

            switch relationship {
            case .muted:
                _ = try await application.createUserMute(
                    userId: try viewer.requireID(),
                    mutedUserId: try hiddenUser.requireID(),
                    muteStatuses: true,
                    muteReblogs: false,
                    muteNotifications: false
                )
            case .blocked:
                _ = try await application.createUserBlockedUser(
                    userId: try viewer.requireID(),
                    blockedUserId: try hiddenUser.requireID(),
                    reason: ""
                )
            }

            // Act.
            let usersFromApi = try await application.getResponse(
                as: .user(userName: viewer.userName, password: "p@ssword"),
                to: "/trending/users?limit=1&period=daily",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )

            // Assert.
            #expect(usersFromApi.data.count == 1, "Filtering should happen before applying the page limit.")
            #expect(usersFromApi.data.first?.id == visibleUser.stringId(), "Only visible accounts should be returned.")
            #expect(usersFromApi.data.contains(where: { $0.id == hiddenUser.stringId() }) == false, "Hidden accounts should not be returned.")
        }
        
        @Test
        func `Trending users should not be returned for unauthorized user when public access is disabled`() async throws {
            // Arrange.
            try await application.updateSetting(key: .showTrendingForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try await application.sendRequest(
                to: "/trending/users?limit=2&period=daily",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
