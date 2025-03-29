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
    
    @Suite("ErrorItems (POST /error-items)", .serialized, .tags(.errorItems))
    struct ErrorItemsCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Error item should be created by authorized user")
        func errorItemShouldBeCreatedByAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "laraniokp")
            let errorItemDto = ErrorItemDto(source: .client, code: "898999", message: "This is message from errorItemShouldBeCreatedByAuthorizedUser")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laraniokp", password: "p@ssword"),
                to: "/error-items",
                method: .POST,
                body: errorItemDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let errorItem = try await application.getErrorItem(code: "898999")
            #expect(errorItem?.message == "This is message from errorItemShouldBeCreatedByAuthorizedUser", "Message should be set correctly.")
        }
        
        @Test("Error item should not be created if message was not specified")
        func errorItemShouldNotBeCreatedIfMessageWasNotSpecified() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nikoniokp")
            let errorItemDto = ErrorItemDto(source: .client, code: "898999", message: "")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikoniokp", password: "p@ssword"),
                to: "/error-items",
                method: .POST,
                data: errorItemDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("message") == "is empty")
        }
        
        @Test("Error item should not be created if code is too long")
        func ruleShouldNotBeCreatedIfTextIsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "robotniokp")
            let errorItemDto = ErrorItemDto(source: .client, code: String.createRandomString(length: 11), message: "")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robotniokp", password: "p@ssword"),
                to: "/error-items",
                method: .POST,
                data: errorItemDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("code") == "is greater than maximum of 10 character(s)")
        }
                
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let errorItemDto = ErrorItemDto(source: .client, code: String.createRandomString(length: 10), message: "Test")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/error-items",
                method: .POST,
                body: errorItemDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
