//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("SharedBusinessCards (POST /shared-business-cards)", .serialized, .tags(.sharedBusinessCards))
    struct SharedBusinessCardsCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Shared business card should be created by authorized user.")
        func sharedBusinessCardShouldBeCreatedByAuthorizedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wictorgigopol")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCardDto = SharedBusinessCardDto(title: "Title #1", note: "Note #1")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "wictorgigopol", password: "p@ssword"),
                to: "/shared-business-cards",
                method: .POST,
                body: sharedBusinessCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let businessCardFromDatabase = try await application.getSharedBusinessCard(businessCardId: businessCard.requireID())
            #expect(businessCardFromDatabase.first?.title == "Title #1", "Shared business card title should be saved.")
            #expect(businessCardFromDatabase.first?.note == "Note #1", "Shared business card note should be saved.")
        }
        
        @Test("Shared business card should not be created if title was not specified.")
        func sharedBusinessCardShouldNotBeCreatedIfTitleWasNotSpecified() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "moniaoqgigopol")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCardDto = SharedBusinessCardDto(title: "")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "moniaoqgigopol", password: "p@ssword"),
                to: "/shared-business-cards",
                method: .POST,
                data: sharedBusinessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is less than minimum of 1 character(s)")
        }
        
        @Test("Shared business card should not be created if title is too long.")
        func sharedBusinessCardShouldNotBeCreatedIfTitleIsTooLong() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "renomixgigopol")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCardDto = SharedBusinessCardDto(title: String.createRandomString(length: 201))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "renomixgigopol", password: "p@ssword"),
                to: "/shared-business-cards",
                method: .POST,
                data: sharedBusinessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is greater than maximum of 200 character(s)")
        }
        
        @Test("Shared business card should not be created if note is too long.")
        func sharedBusinessCardShouldNotBeCreatedIfNoteIsTooLong() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "vikolergigopol")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCardDto = SharedBusinessCardDto(title: "Title #11", note: String.createRandomString(length: 501))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "vikolergigopol", password: "p@ssword"),
                to: "/shared-business-cards",
                method: .POST,
                data: sharedBusinessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("note") == "is greater than maximum of 500 character(s) and is not null")
        }
        
        @Test("Unauthorized should be returned for unauthorized user")
        func unauthorizedShouldbeReturnedForUnauthorizedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "hrobikgigopol")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let sharedBusinessCardDto = SharedBusinessCardDto(title: "Title #11")

            // Act.
            let response = try await application.sendRequest(
                to: "/shared-business-cards",
                method: .POST,
                body: sharedBusinessCardDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
