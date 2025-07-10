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
    
    @Suite("Users (GET /users)", .serialized, .tags(.users))
    struct UsersListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of users should be returned for moderatorUser")
        func listOfUsersShouldBeReturnedForModeratorUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinfux")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let users = try await application.getResponse(
                as: .user(userName: "robinfux", password: "p@ssword"),
                to: "/users",
                method: .GET,
                decodeTo: PaginableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(users.size > 0, "Users should be returned.")
            #expect(users.data.count > 0, "Some users should be returned.")
        }
        
        @Test("List of users should be returned for administratorUser")
        func listOfUsersShouldBeReturnedForAdministratorUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "wikifux")
            try await application.attach(user: user1, role: Role.administrator)
            
            // Act.
            let users = try await application.getResponse(
                as: .user(userName: "wikifux", password: "p@ssword"),
                to: "/users?sortColumn=createdAt",
                method: .GET,
                decodeTo: PaginableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(users.size > 0, "Users should be returned.")
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
            let users = try await application.getResponse(
                as: .user(userName: "tobyfux", password: "p@ssword"),
                to: "/users?query=karolfux&sortColumn=statusesCount",
                method: .GET,
                decodeTo: PaginableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(users.size > 0, "Users should be returned.")
            #expect(users.data.count == 1, "Filtered user should be returned.")
            #expect(users.data.first?.userName == "karolfux", "Correct user should be filtered")
        }
        
        @Test("Filtered list of users should be returned when local filter is applied")
        func filteredListOfUsersShouldBeReturnedWhenLocalFilterIsApplied() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "g0rg1_1fux", isLocal: true)
            _ = try await application.createUser(userName: "g0rg1_2fux", isLocal: false)
            
            let user = try await application.createUser(userName: "marianfux")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let users = try await application.getResponse(
                as: .user(userName: "marianfux", password: "p@ssword"),
                to: "/users?query=g0rg1&onlyLocal=true",
                method: .GET,
                decodeTo: PaginableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(users.size > 0, "Users should be returned.")
            #expect(users.data.count == 1, "Filtered user should be returned.")
            #expect(users.data.first?.userName == "g0rg1_1fux", "Correct user should be filtered")
        }
        
        @Test("Sorted list of users should be returned when sort by username is applied")
        func sortedListOfUsersShouldBeReturnedWhenSortByUsernamIsApplied() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "zbigniewzoltx")
            _ = try await application.createUser(userName: "annazoltx")
            _ = try await application.createUser(userName: "karolzoltx")
            
            let user = try await application.createUser(userName: "bogdanzoltx")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let users = try await application.getResponse(
                as: .user(userName: "bogdanzoltx", password: "p@ssword"),
                to: "/users?query=zoltx&sortColumn=userName&sortDirection=ascending",
                method: .GET,
                decodeTo: PaginableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(users.data.count == 4, "Filtered user should be returned.")
            #expect(users.data[0].userName == "annazoltx", "First sorted user should be returned")
            #expect(users.data[1].userName == "bogdanzoltx", "Second sorted user should be returned")
            #expect(users.data[2].userName == "karolzoltx", "Third sorted user should be returned")
            #expect(users.data[3].userName == "zbigniewzoltx", "Fourth sorted user should be returned")
        }
        
        @Test("Sorted list of users should be returned when sort by last login is applied")
        func sortedListOfUsersShouldBeReturnedWhenSortByLastLoginIsApplied() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "zbigniewreximx")
            let user2 = try await application.createUser(userName: "annareximx")
            let user3 = try await application.createUser(userName: "karolreximx")
            
            let user4 = try await application.createUser(userName: "bogdantestx")
            try await application.attach(user: user4, role: Role.moderator)
            
            user1.lastLoginDate = Date(timeIntervalSinceNow: -3600)
            user2.lastLoginDate = Date(timeIntervalSinceNow: -3000)
            user3.lastLoginDate = Date(timeIntervalSinceNow: -2000)
            
            try await user1.save(on: application.db)
            try await user2.save(on: application.db)
            try await user3.save(on: application.db)
            
            // Act.
            let users = try await application.getResponse(
                as: .user(userName: "bogdantestx", password: "p@ssword"),
                to: "/users?query=reximx&sortColumn=lastLoginDate&sortDirection=descending",
                method: .GET,
                decodeTo: PaginableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(users.data.count == 3, "Filtered user should be returned.")
            #expect(users.data[0].userName == "karolreximx", "First sorted user should be returned")
            #expect(users.data[1].userName == "annareximx", "Second sorted user should be returned")
            #expect(users.data[2].userName == "zbigniewreximx", "Third sorted user should be returned")
        }
        
        @Test("Bad request should be returned when sort column is not supported")
        func badRequestShouldBeReturnedWhenSortColumnIsNotSupported() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "trelgribix")

            let user = try await application.createUser(userName: "mortengribix")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "mortengribix", password: "p@ssword"),
                to: "/users?sortColumn=name",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be forbidden (400).")
            #expect(response.error.code == "sortColumnNotSupported", "Error code should be equal 'sortColumnNotSupported'.")
        }
        
        @Test("Forbidden shouldbe returned for regular user")
        func forbiddenShouldbeReturnedForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "trelfux")
            _ = try await application.createUser(userName: "mortenfux")
            
            // Act.
            let response = try await application.getErrorResponse(
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
            let response = try await application.sendRequest(to: "/users", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
