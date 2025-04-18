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
    
    @Suite("FollowRequests (GET /follow-requests)", .serialized, .tags(.followRequests))
    struct FollowRequestsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Follow requests list should be returned for authorize user")
        func followRequestsListShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictorgorgo")
            let user2 = try await application.createUser(userName: "mariangorgo")
            let user3 = try await application.createUser(userName: "annagorgo")
            let user4 = try await application.createUser(userName: "mariagorgo")
            
            let oldestFollow = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
            _ = try await application.createFollow(sourceId: user3.requireID(), targetId: user1.requireID(), approved: false)
            let newestFollow = try await application.createFollow(sourceId: user4.requireID(), targetId: user1.requireID(), approved: false)
            
            // Act.
            let followRequests = try await application.getResponse(
                as: .user(userName: "wictorgorgo", password: "p@ssword"),
                to: "/follow-requests",
                method: .GET,
                decodeTo: LinkableResultDto<RelationshipDto>.self
            )
            
            // Assert.
            #expect(followRequests.data.count == 3, "All follow requests should be returned.")
            #expect(followRequests.minId == newestFollow.stringId(), "Min Id should be returned.")
            #expect(followRequests.maxId == oldestFollow.stringId(), "Max Id should be returned.")
            
            let user2Relationship = followRequests.data.first(where: { $0.userId == user2.stringId() })
            #expect(user2Relationship?.following == false, "User 2 is not following yet User 1.")
            #expect(user2Relationship?.requestedBy == true, "User 2 requested following User 1.")
            
            let user3Relationship = followRequests.data.first(where: { $0.userId == user3.stringId() })
            #expect(user3Relationship?.following == false, "User 3 is not following yet User 1.")
            #expect(user3Relationship?.requestedBy == true, "User 3 requested following User 1.")
            
            let user4Relationship = followRequests.data.first(where: { $0.userId == user4.stringId() })
            #expect(user4Relationship?.following == false, "User 4 is not following yet User 1.")
            #expect(user4Relationship?.requestedBy == true, "User 4 requested following User 1.")
        }
        
        @Test("First page of follow requests should be returned when size has been specified")
        func firstPageOfFollowRequestsShouldBeReturnedWhenSizeHasBeenSpecified() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "rikigorgo")
            let user2 = try await application.createUser(userName: "yokogorgo")
            let user3 = try await application.createUser(userName: "ulagorgo")
            let user4 = try await application.createUser(userName: "olagorgo")
            
            let oldestFollow = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
            _ = try await application.createFollow(sourceId: user3.requireID(), targetId: user1.requireID(), approved: false)
            _ = try await application.createFollow(sourceId: user4.requireID(), targetId: user1.requireID(), approved: false)
            
            // Act.
            let followRequests = try await application.getResponse(
                as: .user(userName: "rikigorgo", password: "p@ssword"),
                to: "/follow-requests?minId=\(oldestFollow.stringId() ?? "")&size=10",
                method: .GET,
                decodeTo: LinkableResultDto<RelationshipDto>.self
            )
            
            // Assert.
            #expect(followRequests.data.count == 2, "All follow requests should be returned.")
        }
        
        @Test("Follow requests should not be returned for unauthorized user")
        func followRequestsShouldNotBeReturnedForUnauthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "hermangorgo")
            let user2 = try await application.createUser(userName: "robingorgo")
            
            _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/follow-requests?page=0&size=2",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
