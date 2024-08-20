//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class AuthenticationClientsDeleteActionTests: CustomTestCase {

    func testAuthClientShouldBeDeletedIfAuthClientExistsAndUserIsSuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "alinayork")
        try await user.attach(role: Role.administrator)
        let authClientToDelete = try await AuthClient.create(type: .apple, name: "Apple", uri: "client-to-delete-01", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "alinayork", password: "p@ssword"),
            to: "/auth-clients/\(authClientToDelete.stringId() ?? "")",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let authClient = try? await AuthClient.get(uri: "client-to-delete-01")
        XCTAssert(authClient == nil, "Auth client should be deleted.")
    }

    func testAuthClientShouldNotBeDeletedIfAuthClientExistsButUserIsNotSuperUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "robinyork")
        let authClientToDelete = try await AuthClient.create(type: .apple, name: "Apple", uri: "client-to-delete-02", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "robinyork", password: "p@ssword"),
            to: "/auth-clients/\(authClientToDelete.stringId() ?? "")",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be bad request (400).")
    }

    func testCorrectStatusCodeShouldBeReturnedIfAuthClientNotExists() async throws {

        // Arrange.
        let user = try await User.create(userName: "wikiyork")
        try await user.attach(role: Role.administrator)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "wikiyork", password: "p@ssword"),
            to: "/auth-clients/542863",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
