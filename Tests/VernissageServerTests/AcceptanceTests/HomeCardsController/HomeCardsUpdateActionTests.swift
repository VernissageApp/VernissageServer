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
    
    @Suite("HomeCards (PUT /home-cards/:id)", .serialized, .tags(.homeCards))
    struct HomeUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Home card should be updated by administrator`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laratrop")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalHomeCard = try await application.createHomeCard(title: "U0001", body: "Body U0001", order: 101)
            let homeCardDto = HomeCardDto(title: "U0001 - UPDATED", body: "Body U0001 - UPDATED", order: 201)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laratrop", password: "p@ssword"),
                to: "/home-cards/" + (orginalHomeCard.stringId() ?? ""),
                method: .PUT,
                body: homeCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let homeCard = try await application.getHomeCard(title: "U0001 - UPDATED")
            #expect(homeCard?.body == "Body U0001 - UPDATED")
            #expect(homeCard?.order == 201)
        }
        
        @Test
        func `Home card should not be updated if name was not specified`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikotrop")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalHomeCard = try await application.createHomeCard(title: "U0002", body: "Body U0002", order: 101)
            let homeCardDto = HomeCardDto(title: "", body: "Body U0002 - UPDATED", order: 201)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikotrop", password: "p@ssword"),
                to: "/home-cards/" + (orginalHomeCard.stringId() ?? ""),
                method: .PUT,
                data: homeCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is empty")
        }
        
        @Test
        func `Home card should not be updated if body was not specified`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "eniotrop")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalHomeCard = try await application.createHomeCard(title: "U0002", body: "Body U0002", order: 101)
            let homeCardDto = HomeCardDto(title: "U0002 - UPDATED", body: "", order: 201)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "eniotrop", password: "p@ssword"),
                to: "/home-cards/" + (orginalHomeCard.stringId() ?? ""),
                method: .PUT,
                data: homeCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("body") == "is empty")
        }
        
        @Test
        func `Home card should not be updated if title is too long`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robottrop")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalHomeCard = try await application.createHomeCard(title: "U0002", body: "Body U0002", order: 101)
            let homeCardDto = HomeCardDto(title: String.createRandomString(length: 201), body: "Body U0002 - UPDATED", order: 201)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robottrop", password: "p@ssword"),
                to: "/home-cards/" + (orginalHomeCard.stringId() ?? ""),
                method: .PUT,
                data: homeCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is greater than maximum of 200 character(s)")
        }
        
        @Test
        func `Home card should not be updated if body is too long`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "annatrop")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalHomeCard = try await application.createHomeCard(title: "U0002", body: "Body U0002", order: 101)
            let homeCardDto = HomeCardDto(title: "U0002 - UPDATED", body: String.createRandomString(length: 1001), order: 201)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "annatrop", password: "p@ssword"),
                to: "/home-cards/" + (orginalHomeCard.stringId() ?? ""),
                method: .PUT,
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
            _ = try await application.createUser(userName: "nogotrop")
            let orginalHomeCard = try await application.createHomeCard(title: "U0005", body: "Body U0005", order: 101)
            let homeCardDto = HomeCardDto(title: "U0005 - UPDATED", body: "Body U0005 - UPDATED", order: 201)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogotrop", password: "p@ssword"),
                to: "/home-cards/" + (orginalHomeCard.stringId() ?? ""),
                method: .PUT,
                body: homeCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test
        func `Unauthorize should be returnedd for not authorized user`() async throws {
            
            // Arrange.
            let orginalHomeCard = try await application.createHomeCard(title: "U0005", body: "Body U0005", order: 101)
            let homeCardDto = HomeCardDto(title: "U0005 - UPDATED", body: "Body U0005 - UPDATED", order: 201)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/home-cards/" + (orginalHomeCard.stringId() ?? ""),
                method: .PUT,
                body: homeCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
