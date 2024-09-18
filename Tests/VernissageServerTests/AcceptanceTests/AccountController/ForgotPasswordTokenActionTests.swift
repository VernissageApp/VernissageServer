//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

@Suite("POST /forgot/token", .serialized, .tags(.account))
struct TokenActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }
    
    @Test("Forgot password token should be generated for active user")
    func forgotPasswordTokenShouldBeGeneratedForActiveUser() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "johnred")
        let forgotPasswordRequestDto = ForgotPasswordRequestDto(email: "johnred@testemail.com", redirectBaseUrl: "http://localhost:4200")

        // Act.
        let response = try application.sendRequest(
            to: "/account/forgot/token",
            method: .POST,
            body: forgotPasswordRequestDto)

        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }

    @Test("Forgot password token should not be generated if email not exists")
    func forgotPasswordTokenShouldNotBeGeneratedIfEmailNotExists() throws {

        // Arrange.
        let forgotPasswordRequestDto = ForgotPasswordRequestDto(email: "not-exists@testemail.com", redirectBaseUrl: "http://localhost:4200")

        // Act.
        let response = try application.sendRequest(
            to: "/account/forgot/token",
            method: .POST,
            body: forgotPasswordRequestDto)

        // Assert.
        #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    @Test("Forgot password token should not be generated if user is blocked")
    func forgotPasswordTokenShouldNotBeGeneratedIfUserIsBlocked() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "wikired", isBlocked: true)
        let forgotPasswordRequestDto = ForgotPasswordRequestDto(email: "wikired@testemail.com", redirectBaseUrl: "http://localhost:4200")

        // Act.
        let errorResponse = try application.getErrorResponse(
            to: "/account/forgot/token",
            method: .POST,
            data: forgotPasswordRequestDto
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        #expect(errorResponse.error.code == "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
    }
}
