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
    
    @Suite("Timelines (GET /timelines/featured-users)", .serialized, .tags(.timelines))
    struct TimelinesFeaturedUsersActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Users should be returned without params")
        func usersShouldBeReturnedWithoutParams() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showEditorsUsersChoiceForAnonymous, value: .boolean(true))
            
            let user1 = try await application.createUser(userName: "featureXUser1")
            let user2 = try await application.createUser(userName: "featureXUser2")
            let user3 = try await application.createUser(userName: "featureXUser3")
            let user4 = try await application.createUser(userName: "featureXUser4")
            _ = try await application.createFeaturedUser(user: user1, users: [user1, user2, user3, user4])
            
            // Act.
            let usersFromApi = try application.getResponse(
                as: .user(userName: "featureXUser1", password: "p@ssword"),
                to: "/timelines/featured-users?limit=2",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            // Assert.
            #expect(usersFromApi.data.count == 2, "Users list should be returned.")
            #expect(usersFromApi.data[0].userName == "featureXUser4", "First user is not visible.")
            #expect(usersFromApi.data[1].userName == "featureXUser3", "Second user is not visible.")
        }
        
        @Test("Users should be returned with minId")
        func usersShouldBeReturnedWithMinId() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showEditorsUsersChoiceForAnonymous, value: .boolean(true))
            
            let user1 = try await application.createUser(userName: "featureYUser1")
            let user2 = try await application.createUser(userName: "featureYUser2")
            let user3 = try await application.createUser(userName: "featureYUser3")
            let user4 = try await application.createUser(userName: "featureYUser4")
            let featuredUsers = try await application.createFeaturedUser(user: user1, users: [user1, user2, user3, user4])
            
            // Act.
            let usersFromApi = try application.getResponse(
                as: .user(userName: "featureYUser1", password: "p@ssword"),
                to: "/timelines/featured-users?limit=2&minId=\(featuredUsers[1].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
                        
            // Assert.
            #expect(usersFromApi.data.count == 2, "Users list should be returned.")
            #expect(usersFromApi.data[0].userName == "featureYUser4", "First user is not visible.")
            #expect(usersFromApi.data[1].userName == "featureYUser3", "Second user is not visible.")
        }
        
        @Test("Users should be returned with maxId")
        func usersShouldBeReturnedWithMaxId() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showEditorsUsersChoiceForAnonymous, value: .boolean(true))
            
            let user1 = try await application.createUser(userName: "featureZUser1")
            let user2 = try await application.createUser(userName: "featureZUser2")
            let user3 = try await application.createUser(userName: "featureZUser3")
            let user4 = try await application.createUser(userName: "featureZUser4")
            let featuredUsers = try await application.createFeaturedUser(user: user1, users: [user1, user2, user3, user4])
            
            // Act.
            let usersFromApi = try application.getResponse(
                as: .user(userName: "featureZUser1", password: "p@ssword"),
                to: "/timelines/featured-users?limit=2&maxId=\(featuredUsers[2].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(usersFromApi.data.count == 2, "Users list should be returned.")
            #expect(usersFromApi.data[0].userName == "featureZUser2", "First status is not visible.")
            #expect(usersFromApi.data[1].userName == "featureZUser1", "Second status is not visible.")
        }
        
        @Test("Statuses should be returned with sinceId")
        func statusesShouldBeReturnedWithSinceId() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showEditorsUsersChoiceForAnonymous, value: .boolean(true))
            
            let user1 = try await application.createUser(userName: "featureWUser1")
            let user2 = try await application.createUser(userName: "featureWUser2")
            let user3 = try await application.createUser(userName: "featureWUser3")
            let user4 = try await application.createUser(userName: "featureWUser4")
            let featuredUsers = try await application.createFeaturedUser(user: user1, users: [user1, user2, user3, user4])
            
            // Act.
            let statusesFromApi = try application.getResponse(
                as: .user(userName: "featureWUser1", password: "p@ssword"),
                to: "/timelines/featured-users?limit=20&sinceId=\(featuredUsers[0].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 3, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].userName == "featureWUser4", "First status is not visible.")
            #expect(statusesFromApi.data[1].userName == "featureWUser3", "Second status is not visible.")
            #expect(statusesFromApi.data[2].userName == "featureWUser2", "Third status is not visible.")
        }
        
        @Test("Users should not be returned when public access is disabled")
        func usersShouldNotBeReturnedWhenPublicAccessIsDisabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .showEditorsUsersChoiceForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try application.sendRequest(
                to: "/timelines/featured-users?limit=2",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
