//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class AuthenticationClientsCreateActionTests: CustomTestCase {

    func testAuthClientShouldBeCreatedBySuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "borisriq")
        try await user.attach(role: "administrator")
        let authClientDto = AuthClientDto(type: .microsoft, name: "Microsoft", uri: "microsoft", tenantId: "123", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "<svg />")

        // Act.
        let createdAuthDtoDto = try SharedApplication.application().getResponse(
            as: .user(userName: "borisriq", password: "p@ssword"),
            to: "/auth-clients",
            method: .POST,
            data: authClientDto,
            decodeTo: AuthClientDto.self
        )

        // Assert.
        XCTAssert(createdAuthDtoDto.id != nil, "Auth client wasn't created.")
    }
    
    func testCreatedStatusCodeShouldBeReturnedAfterCreatingNewAuthClient() async throws {

        // Arrange.
        let user = try await User.create(userName: "martinriq")
        try await user.attach(role: "administrator")
        let authClientDto = AuthClientDto(type: .google, name: "Google", uri: "google", tenantId: "123", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "<svg />")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "martinriq", password: "p@ssword"),
            to: "/auth-clients",
            method: .POST,
            body: authClientDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.created, "Response http status code should be created (201).")
    }
    
    func testHeaderLocationShouldBeReturnedAfterCreatingNewAuthClient() async throws {

        // Arrange.
        let user = try await User.create(userName: "victoreiq")
        try await user.attach(role: "administrator")
        let authClientDto = AuthClientDto(type: .apple, name: "Apple", uri: "apple", tenantId: "123", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "<svg />")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "victoreiq", password: "p@ssword"),
            to: "/auth-clients",
            method: .POST,
            body: authClientDto
        )

        // Assert.
        let location = response.headers.first(name: .location)
        let authClient = try response.content.decode(AuthClientDto.self)
        XCTAssertEqual(location, "/auth-clients/\(authClient.id ?? "")", "Location header should contains created role id.")
    }
    
    func testAuthClientShouldNotBeCreatedIfUserIsNotSuperUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "robincriq")
        let authClientDto = AuthClientDto(type: .apple, name: "Apple", uri: "apple-01", tenantId: "123", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "<svg />")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "robincriq", password: "p@ssword"),
            to: "/auth-clients",
            method: .POST,
            body: authClientDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testAuthClientShouldNotBeCreatedIfAuthClientWithSameUriExists() async throws {

        // Arrange.
        let user = try await User.create(userName: "erikriq")
        try await user.attach(role: "administrator")
        _ = try await AuthClient.create(type: .apple, name: "Apple", uri: "apple-with-uri", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
        
        let authClientDto = AuthClientDto(type: .apple, name: "Apple", uri: "apple-with-uri", tenantId: "123", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "<svg />")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "erikriq", password: "p@ssword"),
            to: "/auth-clients",
            method: .POST,
            data: authClientDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "authClientWithUriExists", "Error code should be equal 'authClientWithUriExists'.")
    }
}
