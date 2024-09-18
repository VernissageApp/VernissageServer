//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

@Suite("PUT /email", .serialized, .tags(.account))
struct ChangeEmailActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }
        
    @Test("Email should be changed when authorized user change email")
    func emailShouldBeChangedWhenAuthorizedUserChangeEmail() async throws {
        // Arrange.
        _ = try await application.createUser(userName: "tomrock")
        let changeEmailDto = ChangeEmailDto(email: "newemail@vernissage.photos", redirectBaseUrl: "http://localhost:8080/")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "tomrock", password: "p@ssword"),
            to: "/account/email",
            method: .PUT,
            body: changeEmailDto
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userAfterRequest = try await application.getUser(userName: "tomrock")
        #expect(userAfterRequest.email == "newemail@vernissage.photos", "User email should be changed.")
    }
    
    @Test("testEmailShouldNotBeChangedWhenNotAuthorizedUserTriesToChangeEmail")
    func emailShouldNotBeChangedWhenNotAuthorizedUserTriesToChangeEmail() async throws {

        // Arrange.
        let changeEmailDto = ChangeEmailDto(email: "newemail@vernissage.photos", redirectBaseUrl: "http://localhost:8080/")

        // Act.
        let response = try application.sendRequest(
            to: "/account/email",
            method: .PUT,
            body: changeEmailDto
        )

        // Assert.
        #expect(response.status ==  HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    @Test("testEmailShouldNotBeChangedWhenIsNotValid")
    func emailShouldNotBeChangedWhenIsNotValid() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "henrykrock")
        let changeEmailDto = ChangeEmailDto(email: "someemail@test", redirectBaseUrl: "http://localhost:8080/")
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "henrykrock", password: "p@ssword"),
            to: "/account/email",
            method: .PUT,
            data: changeEmailDto
        )
        
        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("email") == "is not a valid email address")
    }
    
    @Test("testEmailShouldNotBeChangedWhenItIsAlreadyUsed")
    func emailShouldNotBeChangedWhenItIsAlreadyUsed() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "ronaldrock")
        _ = try await application.createUser(userName: "rafaeldrock")
        let changeEmailDto = ChangeEmailDto(email: "rafaeldrock@testemail.com", redirectBaseUrl: "http://localhost:8080/")
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "ronaldrock", password: "p@ssword"),
            to: "/account/email",
            method: .PUT,
            data: changeEmailDto
        )
        
        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "emailIsAlreadyConnected", "Error code should be equal 'emailIsAlreadyConnected'.")
    }
    
    @Test("testEmailShouldNotBeChangedWhenIsDisposabledEmail")
    func emailShouldNotBeChangedWhenIsDisposabledEmail() async throws {
        
        // Arrange.
        _ = try await application.createDisposableEmail(domain: "10minutes.org")
        _ = try await application.createUser(userName: "kevinkrock")
        let changeEmailDto = ChangeEmailDto(email: "kevinkrock@10minutes.org", redirectBaseUrl: "http://localhost:8080/")
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "kevinkrock", password: "p@ssword"),
            to: "/account/email",
            method: .PUT,
            data: changeEmailDto
        )
        
        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "disposableEmailCannotBeUsed", "Error code should be equal 'disposableEmailCannotBeUsed'.")
    }
}
