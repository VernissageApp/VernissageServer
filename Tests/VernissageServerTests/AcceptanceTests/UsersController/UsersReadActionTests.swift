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

extension UsersControllerTests {
    
    @Suite("GET /:username", .serialized, .tags(.users))
    struct UsersReadActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("testUserProfileShouldBeReturnedForExistingUser")
        func userProfileShouldBeReturnedForExistingUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "johnbush")
            
            // Act.
            let userDto = try application.getResponse(
                as: .user(userName: "johnbush", password: "p@ssword"),
                to: "/users/@johnbush",
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
        
        @Test("testUserProfileShouldNotBeReturnedForNotExistingUser")
        func userProfileShouldNotBeReturnedForNotExistingUser() throws {
            
            // Act.
            let response = try application.sendRequest(to: "/users/@not-exists", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("testPublicProfileShouldNotContainsSensitiveInformation")
        func publicProfileShouldNotContainsSensitiveInformation() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "elizabush")
            
            // Act.
            let userDto = try application.getResponse(to: "/users/@elizabush", decodeTo: UserDto.self)
            
            // Assert.
            #expect(userDto.id == user.stringId(), "Property 'id' should be equal.")
            #expect(userDto.userName == user.userName, "Property 'userName' should be equal.")
            #expect(userDto.name == user.name, "Property 'name' should be equal.")
            #expect(userDto.bio == user.bio, "Property 'bio' should be equal.")
            #expect(userDto.email == nil, "Property 'email' must not be equal.")
        }
    }
}
