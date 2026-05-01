//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("Users (POST /users/:username/move)", .serialized, .tags(.users))
    struct UsersMoveActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Move should migrate local followers to target account`() async throws {
            // Arrange.
            let sourceUser = try await application.createUser(userName: "movesource", generateKeys: true)
            let targetUser = try await application.createUser(userName: "movetarget", generateKeys: true)
            let localFollower = try await application.createUser(userName: "localfollower", generateKeys: true)
            
            _ = try await application.createUserAlias(userId: targetUser.requireID(),
                                                      alias: "movesource@localhost:8080",
                                                      activityPubProfile: sourceUser.activityPubProfile)
            
            _ = try await application.createFollow(sourceId: localFollower.requireID(),
                                                   targetId: sourceUser.requireID(),
                                                   approved: true)
            
            let moveDto = UserMoveDto(account: "movetarget", password: "p@ssword")
            
            // Act.
            let userDto = try await application.getResponse(
                as: .user(userName: "movesource", password: "p@ssword"),
                to: "/users/@movesource/move",
                method: .POST,
                data: moveDto,
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(userDto.movedTo?.activityPubProfile == targetUser.activityPubProfile)
            
            let oldFollow = try await application.getFollow(sourceId: localFollower.requireID(), targetId: sourceUser.requireID())
            #expect(oldFollow == nil, "Follower should no longer follow source account.")
            
            let newFollow = try await application.getFollow(sourceId: localFollower.requireID(), targetId: targetUser.requireID())
            #expect(newFollow != nil, "Follower should follow target account.")
        }
        
        @Test
        func `Move should fail when target account is not an alias`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "movesource2", generateKeys: true)
            _ = try await application.createUser(userName: "movetarget2", generateKeys: true)
            let moveDto = UserMoveDto(account: "movetarget2", password: "p@ssword")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "movesource2", password: "p@ssword"),
                to: "/users/@movesource2/move",
                method: .POST,
                data: moveDto
            )
            
            // Assert.
            #expect(errorResponse.status == .badRequest)
            #expect(errorResponse.error.code == AccountMigrationError.targetAccountIsNotAlias.rawValue)
        }
        
        @Test
        func `Move should fail when password is invalid`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "movesource3", generateKeys: true)
            let moveDto = UserMoveDto(account: "movetarget3", password: "invalid-password")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "movesource3", password: "p@ssword"),
                to: "/users/@movesource3/move",
                method: .POST,
                data: moveDto
            )
            
            // Assert.
            #expect(errorResponse.status == .badRequest)
            #expect(errorResponse.error.code == LoginError.invalidLoginCredentials.rawValue)
        }
    }
}
