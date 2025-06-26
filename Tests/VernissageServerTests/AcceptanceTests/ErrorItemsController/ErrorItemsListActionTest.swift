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
    
    @Suite("ErrorItems (GET /error-items)", .serialized, .tags(.errorItems))
    struct ErrorItemsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of error items should be returned for moderator")
        func listOfErrorItemsShouldBeReturnedForModerator() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinporix")
            try await application.attach(user: user, role: Role.moderator)
            _ = try await application.createErrorItem(message: "This is error message!")
            
            // Act.
            let errorItems = try await application.getResponse(
                as: .user(userName: "robinporix", password: "p@ssword"),
                to: "/error-items",
                method: .GET,
                decodeTo: PaginableResultDto<ErrorItemDto>.self
            )
            
            // Assert.
            #expect(errorItems.data.count > 0, "Error items list wasn't returned.")
        }
        
        @Test("Specific error item should be returned for moderator when filtered by code")
        func specificErrorItemShouldBeReturnedForModeratorWhenFilteredByCode() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "annaporix")
            try await application.attach(user: user, role: Role.moderator)
            
            let code = String.createRandomString(length: 10)
            _ = try await application.createErrorItem(code: code, message: "This is error message!")
            
            // Act.
            let errorItems = try await application.getResponse(
                as: .user(userName: "annaporix", password: "p@ssword"),
                to: "/error-items?query=\(code)",
                method: .GET,
                decodeTo: PaginableResultDto<ErrorItemDto>.self
            )
            
            // Assert.
            #expect(errorItems.data.count == 1, "One error item wasn't returned.")
            #expect(errorItems.data.first?.code == code, "Correct error item wasn't returned.")
        }
        
        @Test("Specific error item should be returned for moderator when filtered by message")
        func specificErrorItemShouldBeReturnedForModeratorWhenFilteredByMessage() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "violaporix")
            try await application.attach(user: user, role: Role.moderator)
            
            let code = String.createRandomString(length: 10)
            _ = try await application.createErrorItem(code: code, message: "Critical announce error!")
            
            // Act.
            let errorItems = try await application.getResponse(
                as: .user(userName: "violaporix", password: "p@ssword"),
                to: "/error-items?query=announce error",
                method: .GET,
                decodeTo: PaginableResultDto<ErrorItemDto>.self
            )
            
            // Assert.
            #expect(errorItems.data.count == 1, "One error item wasn't returned.")
            #expect(errorItems.data.first?.code == code, "Correct error item wasn't returned.")
        }
        
        @Test("List of error items should not be returned for not super user")
        func listOfErrorItemsShouldNotBeReturnedForNotSuperUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "wictorporix")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "wictorporix", password: "p@ssword"),
                to: "/error-items",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be bad request (400).")
        }
    }
}
