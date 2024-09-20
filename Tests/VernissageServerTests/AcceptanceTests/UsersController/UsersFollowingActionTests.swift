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
    
    @Suite("Users (GET /users/:username/following)", .serialized, .tags(.users))
    struct UsersFollowingActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Following list should be returned")
        func followingListShouldBeReturned() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictortroga")
            let user2 = try await application.createUser(userName: "mariantroga")
            let user3 = try await application.createUser(userName: "ronaldtroga")
            let user4 = try await application.createUser(userName: "annatroga")
            let user5 = try await application.createUser(userName: "roktroga")
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user3.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user4.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user5.requireID(), approved: true)
            
            // Act.
            let following = try application.getResponse(
                to: "/users/\(user1.userName)/following",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(following.data.count == 4, "All following users should be returned.")
        }
        
        @Test("Following filtered by minId should be returned")
        func followingFilteredByMinIdShouldBeReturned() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictorrquix")
            let user2 = try await application.createUser(userName: "marianrquix")
            let user3 = try await application.createUser(userName: "ronaldrquix")
            let user4 = try await application.createUser(userName: "annarquix")
            let user5 = try await application.createUser(userName: "rokrquix")
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            let secondFollow = try await application.createFollow(sourceId: user1.requireID(), targetId: user3.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user4.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user5.requireID(), approved: true)
            
            // Act.
            let following = try application.getResponse(
                to: "/users/\(user1.userName)/following?minId=\(secondFollow.stringId() ?? "")",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(following.data.count == 2, "All following users should be returned.")
            #expect(following.data[0].id == user5.stringId(), "First user should be returned.")
            #expect(following.data[1].id == user4.stringId(), "Second user should be returned.")
        }
        
        @Test("Following filtered by maxId should be returned")
        func followingFilteredByMaxIdShouldBeReturned() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictortovin")
            let user2 = try await application.createUser(userName: "mariantovin")
            let user3 = try await application.createUser(userName: "ronaldtovin")
            let user4 = try await application.createUser(userName: "annatovin")
            let user5 = try await application.createUser(userName: "roktovin")
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user3.requireID(), approved: true)
            let thirdFollow = try await application.createFollow(sourceId: user1.requireID(), targetId: user4.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user5.requireID(), approved: true)
            
            // Act.
            let following = try application.getResponse(
                to: "/users/\(user1.userName)/following?maxId=\(thirdFollow.stringId() ?? "")",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(following.data.count == 2, "All following users should be returned.")
            #expect(following.data[0].id == user3.stringId(), "Previous user should be returned.")
            #expect(following.data[1].id == user2.stringId(), "Last user should be returned.")
        }
        
        @Test("Following list based on limit should be returned")
        func followingListBasedOnLimitShouldBeReturned() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictorgrovix")
            let user2 = try await application.createUser(userName: "mariangrovix")
            let user3 = try await application.createUser(userName: "ronaldgrovix")
            let user4 = try await application.createUser(userName: "annagrovix")
            let user5 = try await application.createUser(userName: "rokgrovix")
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user3.requireID(), approved: true)
            let thirdFollow = try await application.createFollow(sourceId: user1.requireID(), targetId: user4.requireID(), approved: true)
            let fourthFollow = try await application.createFollow(sourceId: user1.requireID(), targetId: user5.requireID(), approved: true)
            
            // Act.
            let following = try application.getResponse(
                to: "/users/\(user1.userName)/following?limit=2",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(following.data.count == 2, "All following users should be returned.")
            #expect(following.maxId == thirdFollow.stringId(), "MaxId should be returned.")
            #expect(following.minId == fourthFollow.stringId(), "MinId should be returned.")
        }
    }
}
