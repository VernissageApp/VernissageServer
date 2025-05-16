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
    
    @Suite("Users (GET /users/:username)", .serialized, .tags(.users))
    struct UsersReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User profile should be returned for existing user by user name")
        func userProfileShouldBeReturnedForExistingUserByUserName() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "johnbush")
            
            // Act.
            let userDto = try await application.getResponse(
                as: .user(userName: "johnbush", password: "p@ssword"),
                to: "/users/@johnbush",
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(userDto.id == user.stringId(), "Property 'id' should be equal.")
            #expect(userDto.type == .person, "Property 'type' should be equal.")
            #expect(userDto.account == user.account, "Property 'userName' should be equal.")
            #expect(userDto.userName == user.userName, "Property 'userName' should be equal.")
            #expect(userDto.email == user.email, "Property 'email' should be equal.")
            #expect(userDto.name == user.name, "Property 'name' should be equal.")
            #expect(userDto.bio == user.bio, "Property 'bio' should be equal.")
            #expect(userDto.publishedAt != nil, "Property 'publishedAt' should be returned.")
        }
        
        @Test("User profile should be returned for existing user by full user name")
        func userProfileShouldBeReturnedForExistingUserByFullUserName() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "boliobush")
            
            // Act.
            let userDto = try await application.getResponse(
                as: .user(userName: "boliobush", password: "p@ssword"),
                to: "/users/@boliobush@localhost:8080",
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(userDto.id == user.stringId(), "Property 'id' should be equal.")
            #expect(userDto.account == user.account, "Property 'userName' should be equal.")
            #expect(userDto.userName == user.userName, "Property 'userName' should be equal.")
            #expect(userDto.email == user.email, "Property 'email' should be equal.")
            #expect(userDto.name == user.name, "Property 'name' should be equal.")
            #expect(userDto.bio == user.bio, "Property 'bio' should be equal.")
        }
                
        @Test("User profile should be returned for existing user by user id")
        func userProfileShouldBeReturnedForExistingUserByUserId() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "clarabush")
            
            // Act.
            let userDto = try await application.getResponse(
                as: .user(userName: "clarabush", password: "p@ssword"),
                to: "/users/" + (user.stringId() ?? ""),
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(userDto.id == user.stringId(), "Property 'id' should be equal.")
            #expect(userDto.account == user.account, "Property 'userName' should be equal.")
            #expect(userDto.userName == user.userName, "Property 'userName' should be equal.")
            #expect(userDto.email == user.email, "Property 'email' should be equal.")
            #expect(userDto.name == user.name, "Property 'name' should be equal.")
            #expect(userDto.bio == user.bio, "Property 'bio' should be equal.")
        }
        
        @Test("User profile should not be returned for not existing user")
        func userProfileShouldNotBeReturnedForNotExistingUser() async throws {
            
            // Act.
            let response = try await application.sendRequest(to: "/users/@not-exists", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Public profile should not contains sensitive information")
        func publicProfileShouldNotContainsSensitiveInformation() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "elizabush")
            
            // Act.
            let userDto = try await application.getResponse(to: "/users/@elizabush", decodeTo: UserDto.self)
            
            // Assert.
            #expect(userDto.id == user.stringId(), "Property 'id' should be equal.")
            #expect(userDto.userName == user.userName, "Property 'userName' should be equal.")
            #expect(userDto.name == user.name, "Property 'name' should be equal.")
            #expect(userDto.bio == user.bio, "Property 'bio' should be equal.")
            #expect(userDto.email == nil, "Property 'email' must not be equal.")
        }
    }
}
