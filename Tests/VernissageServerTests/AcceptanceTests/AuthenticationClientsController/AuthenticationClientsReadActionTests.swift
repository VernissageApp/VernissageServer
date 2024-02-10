//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class AuthenticationClientsReadActionTests: CustomTestCase {

    func testAuthClientShouldBeReturnedForSuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robinwath")
        try await user.attach(role: Role.administrator)
        let authClient = try await AuthClient.create(type: .apple, name: "Apple", uri: "client-for-read-01", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")

        // Act.
        let authClientDto = try SharedApplication.application().getResponse(
            as: .user(userName: "robinwath", password: "p@ssword"),
            to: "/auth-clients/\(authClient.stringId() ?? "")",
            method: .GET,
            decodeTo: AuthClientDto.self
        )

        // Assert.
        XCTAssertEqual(authClientDto.id, authClient.stringId(), "Auth client id should be correct.")
        XCTAssertEqual(authClientDto.name, authClient.name, "Auth client name should be correct.")
        XCTAssertEqual(authClientDto.uri, authClient.uri, "Auth client uri should be correct.")
        XCTAssertEqual(authClientDto.callbackUrl, authClient.callbackUrl, "Auth client callbackUrl should be correct.")
        XCTAssertEqual(authClientDto.clientId, authClient.clientId, "Auth client clientId should be correct.")
        XCTAssertEqual(authClientDto.clientSecret, "", "Auth client secret should be empty.")
    }

    func testAuthClientShouldBeReturnedIfUserIsNotSuperUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "rickywath")
        let authClient = try await AuthClient.create(type: .apple, name: "Apple", uri: "client-for-read-02", tenantId: "tenantId", clientId: "clientId", clientSecret: "rickywath", callbackUrl: "callback", svgIcon: "svg")

        // Act.
        let authClientDto = try SharedApplication.application().getResponse(
            as: .user(userName: "robinwath", password: "p@ssword"),
            to: "/auth-clients/\(authClient.stringId() ?? "")",
            method: .GET,
            decodeTo: AuthClientDto.self
        )

        // Assert.
        XCTAssertEqual(authClientDto.id, authClient.stringId(), "Auth client id should be correct.")
        XCTAssertEqual(authClientDto.name, authClient.name, "Auth client name should be correct.")
        XCTAssertEqual(authClientDto.uri, authClient.uri, "Auth client uri should be correct.")
        XCTAssertEqual(authClientDto.callbackUrl, authClient.callbackUrl, "Auth client callbackUrl should be correct.")
        XCTAssertEqual(authClientDto.clientId, authClient.clientId, "Auth client clientId should be correct.")
        XCTAssertEqual(authClientDto.clientSecret, "", "Auth client secret should be empty.")
    }

    func testCorrectStatusCodeShouldBeReturnedIdAuthClientNotExists() async throws {

        // Arrange.
        let user = try await User.create(userName: "tedwarth")
        try await user.attach(role: Role.administrator)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "tedwarth", password: "p@ssword"),
            to: "/auth-clients/76532",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
