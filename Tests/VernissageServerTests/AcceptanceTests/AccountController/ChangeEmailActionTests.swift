//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class ChangeEmailActionTests: CustomTestCase {
    
    func testEmailShouldBeChangedWhenAuthorizedUserChangeEmail() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "tomrock")
        let changeEmailDto = ChangeEmailDto(email: "newemail@vernissage.photos", redirectBaseUrl: "http://localhost:8080/")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "tomrock", password: "p@ssword"),
            to: "/account/email",
            method: .PUT,
            body: changeEmailDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userAfterRequest = try await User.get(userName: "tomrock")
        XCTAssertEqual("newemail@vernissage.photos", userAfterRequest.email, "User email should be changed.")
    }
    
    func testEmailShouldNotBeChangedWhenNotAuthorizedUserTriesToChangeEmail() throws {

        // Arrange.
        let changeEmailDto = ChangeEmailDto(email: "newemail@vernissage.photos", redirectBaseUrl: "http://localhost:8080/")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/account/email",
            method: .PUT,
            body: changeEmailDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testEmailShouldNotBeChangedWhenIsNotValid() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "henrykrock")
        let changeEmailDto = ChangeEmailDto(email: "someemail@test", redirectBaseUrl: "http://localhost:8080/")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "henrykrock", password: "p@ssword"),
            to: "/account/email",
            method: .PUT,
            data: changeEmailDto
        )
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("email"), "is not a valid email address")
    }
    
    func testEmailShouldNotBeChangedWhenItIsAlreadyUsed() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "ronaldrock")
        _ = try await User.create(userName: "rafaeldrock")
        let changeEmailDto = ChangeEmailDto(email: "rafaeldrock@testemail.com", redirectBaseUrl: "http://localhost:8080/")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "ronaldrock", password: "p@ssword"),
            to: "/account/email",
            method: .PUT,
            data: changeEmailDto
        )
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "emailIsAlreadyConnected", "Error code should be equal 'emailIsAlreadyConnected'.")
    }
    
    func testEmailShouldNotBeChangedWhenIsDisposabledEmail() async throws {
        
        // Arrange.
        _ = try await DisposableEmail.create(domain: "10minutes.org")
        _ = try await User.create(userName: "kevinkrock")
        let changeEmailDto = ChangeEmailDto(email: "kevinkrock@10minutes.org", redirectBaseUrl: "http://localhost:8080/")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "kevinkrock", password: "p@ssword"),
            to: "/account/email",
            method: .PUT,
            data: changeEmailDto
        )
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "disposableEmailCannotBeUsed", "Error code should be equal 'disposableEmailCannotBeUsed'.")
    }
}
