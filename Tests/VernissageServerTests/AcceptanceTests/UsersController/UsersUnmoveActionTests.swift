//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("Users (POST /users/:username/unmove)", .serialized, .tags(.users))
    struct UsersUnmoveActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Unmove should clear movedTo for authorized user`() async throws {
            // Arrange.
            let sourceUser = try await application.createUser(userName: "unmovesource", generateKeys: true)
            let targetUser = try await application.createUser(userName: "unmovetarget", generateKeys: true)
            sourceUser.$movedTo.id = try targetUser.requireID()
            try await sourceUser.save(on: application.db)
            
            let unmoveDto = UserUnmoveDto(password: "p@ssword")
            
            // Act.
            let userDto = try await application.getResponse(
                as: .user(userName: "unmovesource", password: "p@ssword"),
                to: "/users/@unmovesource/unmove",
                method: .POST,
                data: unmoveDto,
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(userDto.movedTo == nil)
            
            let refreshedUser = try await application.getUser(id: sourceUser.requireID())
            #expect(try await refreshedUser?.$movedTo.get(on: application.db) == nil)
        }
        
        @Test
        func `Unmove should fail when password is invalid`() async throws {
            // Arrange.
            let sourceUser = try await application.createUser(userName: "unmovesource2", generateKeys: true)
            let targetUser = try await application.createUser(userName: "unmovetarget2", generateKeys: true)
            sourceUser.$movedTo.id = try targetUser.requireID()
            try await sourceUser.save(on: application.db)
            
            let unmoveDto = UserUnmoveDto(password: "invalid-password")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "unmovesource2", password: "p@ssword"),
                to: "/users/@unmovesource2/unmove",
                method: .POST,
                data: unmoveDto
            )
            
            // Assert.
            #expect(errorResponse.status == .badRequest)
            #expect(errorResponse.error.code == LoginError.invalidLoginCredentials.rawValue)
        }
        
        @Test
        func `Unmove should fail for unauthorized user`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "unmovesource3", generateKeys: true)
            let unmoveDto = UserUnmoveDto(password: "p@ssword")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/users/@unmovesource3/unmove",
                method: .POST,
                body: unmoveDto
            )
            
            // Assert.
            #expect(response.status == .unauthorized)
        }
    }
}
