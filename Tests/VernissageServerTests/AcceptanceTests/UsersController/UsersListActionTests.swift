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
    
    @Suite("GET /", .serialized, .tags(.users))
    struct UsersListActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("List of users should be returned for moderatorUser")
        func listOfUsersShouldBeReturnedForModeratorUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinfux")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let users = try application.getResponse(
                as: .user(userName: "robinfux", password: "p@ssword"),
                to: "/users",
                method: .GET,
                decodeTo: PaginableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(users != nil, "Users should be returned.")
            #expect(users.data.count > 0, "Some users should be returned.")
        }
        
        @Test("List of users should be returned for administratorUser")
        func listOfUsersShouldBeReturnedForAdministratorUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "wikifux")
            try await application.attach(user: user1, role: Role.administrator)
            
            // Act.
            let users = try application.getResponse(
                as: .user(userName: "wikifux", password: "p@ssword"),
                to: "/users",
                method: .GET,
                decodeTo: PaginableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(users != nil, "Users should be returned.")
            #expect(users.data.count > 0, "Some users should be returned.")
        }
        
        @Test("Filtered list of users should be returned when filter is applied user")
        func filteredListOfUsersShouldBeReturnedWhenFilterIsAppliedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "kingafux")
            _ = try await application.createUser(userName: "karolfux")
            _ = try await application.createUser(userName: "karlolinafux")
            
            let user = try await application.createUser(userName: "tobyfux")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let users = try application.getResponse(
                as: .user(userName: "tobyfux", password: "p@ssword"),
                to: "/users?query=karolfux",
                method: .GET,
                decodeTo: PaginableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(users != nil, "Users should be returned.")
            #expect(users.data.count == 1, "Filtered user should be returned.")
            #expect(users.data.first?.userName == "karolfux", "Correct user should be filtered")
        }
        
        @Test("Forbidden shouldbe returned for regular user")
        func forbiddenShouldbeReturnedForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "trelfux")
            _ = try await application.createUser(userName: "mortenfux")
            
            // Act.
            let response = try application.getErrorResponse(
                as: .user(userName: "trelfux", password: "p@ssword"),
                to: "/users",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("List of users should not be returned when user is not authorized")
        func listOfUsersShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try application.sendRequest(to: "/users", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
