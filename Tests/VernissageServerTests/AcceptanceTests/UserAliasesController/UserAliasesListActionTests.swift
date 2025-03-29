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
    
    @Suite("UserAliases (GET /user-aliases)", .serialized, .tags(.userAliases))
    struct UserAliasesListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of user aliases should be returned for authorized user")
        func testListOfUserAliasesShouldBeReturnedForAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robintebor")
            _ = try await application.createUserAlias(userId: user.requireID(),
                                                      alias: "robintebor@alias.com",
                                                      activityPubProfile: "https://alias.com/users/robintebor")
            
            // Act.
            let userAliases = try await application.getResponse(
                as: .user(userName: "robintebor", password: "p@ssword"),
                to: "/user-aliases",
                method: .GET,
                decodeTo: [UserAliasDto].self
            )
            
            // Assert.
            #expect(userAliases != nil, "User's aliases should be returned.")
            #expect(userAliases.count == 1, "Some user's aliases should be returned.")
        }
        
        @Test("Only list of user aliases should be returned for authorized user")
        func testOnlyListOfUserAliasesShouldBeReturnedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "annatebor")
            let user2 = try await application.createUser(userName: "mariatebor")
            _ = try await application.createUserAlias(userId: user1.requireID(), alias: "annatebor@alias.com", activityPubProfile: "https://alias.com/users/annatebor")
            _ = try await application.createUserAlias(userId: user2.requireID(), alias: "mariatebor@alias.com", activityPubProfile: "https://alias.com/users/mariatebor")
            
            // Act.
            let userAliases = try await application.getResponse(
                as: .user(userName: "annatebor", password: "p@ssword"),
                to: "/user-aliases",
                method: .GET,
                decodeTo: [UserAliasDto].self
            )
            
            // Assert.
            #expect(userAliases != nil, "User's aliases should be returned.")
            #expect(userAliases.count == 1, "Some user's aliases should be returned.")
            #expect(userAliases.first?.alias == "annatebor@alias.com", "Correct alias should be returned.")
        }
        
        @Test("List of user aliases should not be returned when user is not authorized")
        func testListOfUserAliasesShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/user-aliases", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
