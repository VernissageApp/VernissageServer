//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("HomeCards (POST /home-cards)", .serialized, .tags(.homeCards))
    struct HomeCardsCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Home cards should be created by administrator`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laraenia")
            try await application.attach(user: user, role: Role.moderator)
            
            let homeCardDto = HomeCardDto(title: "H0001", body: "Home card body.", order: 1)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laraenia", password: "p@ssword"),
                to: "/home-cards",
                method: .POST,
                body: homeCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let homeCard = try await application.getHomeCard(title: "H0001")
            #expect(homeCard?.title == "H0001")
            #expect(homeCard?.body == "Home card body.")
        }
        
        @Test
        func `Home card should not be created if title was not specified`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikoenia")
            try await application.attach(user: user, role: Role.moderator)
            
            let homeCardDto = HomeCardDto(title: "", body: "Home card body.", order: 1)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikoenia", password: "p@ssword"),
                to: "/home-cards",
                method: .POST,
                data: homeCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is empty")
        }
        
        @Test
        func `Home card should not be created if body was not specified`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "reniaenia")
            try await application.attach(user: user, role: Role.moderator)
            
            let homeCardDto = HomeCardDto(title: "H0003", body: "", order: 1)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "reniaenia", password: "p@ssword"),
                to: "/home-cards",
                method: .POST,
                data: homeCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("body") == "is empty")
        }
        
        @Test
        func `Home card should not be created if title is too long`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robotenia")
            try await application.attach(user: user, role: Role.moderator)
            
            let homeCardDto = HomeCardDto(title: String.createRandomString(length: 201), body: "Body.", order: 1)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robotenia", password: "p@ssword"),
                to: "/home-cards",
                method: .POST,
                data: homeCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is greater than maximum of 200 character(s)")
        }
        
        @Test
        func `Home card should not be created if body is too long`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "annaenia")
            try await application.attach(user: user, role: Role.moderator)
            
            let homeCardDto = HomeCardDto(title: "H0004", body: String.createRandomString(length: 1001), order: 1)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "annaenia", password: "p@ssword"),
                to: "/home-cards",
                method: .POST,
                data: homeCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("body") == "is greater than maximum of 1000 character(s)")
        }
        
        @Test
        func `Forbidden should be returnedd for regular user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogoenial")
            let homeCardDto = HomeCardDto(title: "H0001", body: "Home card body.", order: 1)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogoenial", password: "p@ssword"),
                to: "/home-cards",
                method: .POST,
                body: homeCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test
        func `Unauthorize should be returnedd for not authorized user`() async throws {
            
            // Arrange.
            let homeCardDto = HomeCardDto(title: "H0001", body: "Home card body.", order: 1)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/home-cards",
                method: .POST,
                body: homeCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
