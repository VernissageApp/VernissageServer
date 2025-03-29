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
    
    @Suite("Users (GET /users/:username/followers)", .serialized, .tags(.users))
    struct UsersFollowersActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Followers list should be returned")
        func followersListShouldBeReturned() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictortrogi")
            let user2 = try await application.createUser(userName: "mariantrogi")
            let user3 = try await application.createUser(userName: "ronaldtrogi")
            let user4 = try await application.createUser(userName: "annatrogi")
            
            _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user3.requireID(), targetId: user1.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user4.requireID(), targetId: user1.requireID(), approved: true)
            
            // Act.
            let followers = try await application.getResponse(
                to: "/users/\(user1.userName)/followers",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(followers.data.count == 3, "All followers should be returned.")
        }
        
        @Test("Following filtered by minId should be returned")
        func followingFilteredByMinIdShouldBeReturned() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictorqowix")
            let user2 = try await application.createUser(userName: "marianqowix")
            let user3 = try await application.createUser(userName: "ronaldqowix")
            let user4 = try await application.createUser(userName: "annaqowix")
            let user5 = try await application.createUser(userName: "rokqowix")
            
            _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
            let secondFollow = try await application.createFollow(sourceId: user3.requireID(), targetId: user1.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user4.requireID(), targetId: user1.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user5.requireID(), targetId: user1.requireID(), approved: true)
            
            // Act.
            let followers = try await application.getResponse(
                to: "/users/\(user1.userName)/followers?minId=\(secondFollow.stringId() ?? "")",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(followers.data.count == 2, "All followers users should be returned.")
            #expect(followers.data[0].id == user5.stringId(), "First user should be returned.")
            #expect(followers.data[1].id == user4.stringId(), "Second user should be returned.")
        }
        
        @Test("Following filtered by maxId should be returned")
        func followingFilteredByMaxIdShouldBeReturned() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictorforqin")
            let user2 = try await application.createUser(userName: "marianforqin")
            let user3 = try await application.createUser(userName: "ronaldforqin")
            let user4 = try await application.createUser(userName: "annaforqin")
            let user5 = try await application.createUser(userName: "rokforqin")
            
            _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user3.requireID(), targetId: user1.requireID(), approved: true)
            let thirdFollow = try await application.createFollow(sourceId: user4.requireID(), targetId: user1.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user5.requireID(), targetId: user1.requireID(), approved: true)
            
            // Act.
            let followers = try await application.getResponse(
                to: "/users/\(user1.userName)/followers?maxId=\(thirdFollow.stringId() ?? "")",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(followers.data.count == 2, "All followers users should be returned.")
            #expect(followers.data[0].id == user3.stringId(), "Previous user should be returned.")
            #expect(followers.data[1].id == user2.stringId(), "Last user should be returned.")
        }
        
        @Test("Following list based on limit should be returned")
        func followingListBasedOnLimitShouldBeReturned() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictorbohen")
            let user2 = try await application.createUser(userName: "marianbohen")
            let user3 = try await application.createUser(userName: "ronaldbohen")
            let user4 = try await application.createUser(userName: "annagbohen")
            let user5 = try await application.createUser(userName: "rokbohen")
            
            _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user3.requireID(), targetId: user1.requireID(), approved: true)
            let thirdFollow = try await application.createFollow(sourceId: user4.requireID(), targetId: user1.requireID(), approved: true)
            let fourthFollow = try await application.createFollow(sourceId: user5.requireID(), targetId: user1.requireID(), approved: true)
            
            // Act.
            let followers = try await application.getResponse(
                to: "/users/\(user1.userName)/followers?limit=2",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(followers.data.count == 2, "All followers users should be returned.")
            #expect(followers.maxId == thirdFollow.stringId(), "MaxId should be returned.")
            #expect(followers.minId == fourthFollow.stringId(), "MinId should be returned.")
        }
    }
}
