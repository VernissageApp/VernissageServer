//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class AuthenticationClientsDeleteActionTests: XCTestCase {

    func testAuthClientShouldBeDeletedIfAuthClientExistsAndUserIsSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "alinayork")
        try user.attach(role: "administrator")
        let authClientToDelete = try AuthClient.create(type: .apple, name: "Apple", uri: "client-to-delete-01", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "alinayork", password: "p@ssword"),
            to: "/auth-clients/\(authClientToDelete.id?.uuidString ?? "")",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let authClient = try? AuthClient.get(uri: "client-to-delete-01")
        XCTAssert(authClient == nil, "Auth client should be deleted.")
    }

    func testAuthClientShouldNotBeDeletedIfAuthClientExistsButUserIsNotSuperUser() throws {

        // Arrange.
        _ = try User.create(userName: "robinyork")
        let authClientToDelete = try AuthClient.create(type: .apple, name: "Apple", uri: "client-to-delete-02", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "robinyork", password: "p@ssword"),
            to: "/auth-clients/\(authClientToDelete.id?.uuidString ?? "")",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be bad request (400).")
    }

    func testCorrectStatusCodeShouldBeReturnedIfAuthClientNotExists() throws {

        // Arrange.
        let user = try User.create(userName: "wikiyork")
        try user.attach(role: "administrator")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "wikiyork", password: "p@ssword"),
            to: "/auth-clients/\(UUID().uuidString)",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
