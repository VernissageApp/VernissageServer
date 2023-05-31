@testable import App
import XCTest
import XCTVapor


final class AuthenticationClientsUpdateActionTests: XCTestCase {

    func testCorrectAuthClientShouldBeUpdatedBySuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "brucevoos")
        try user.attach(role: "administrator")
        let authClient = try AuthClient.create(type: .apple, name: "Apple", uri: "client-for-update-01", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
        let authClientToUpdate = AuthClientDto(type: .microsoft, name: "Microsoft", uri: "client-for-update-01", tenantId: "123", clientId: "clientId", clientSecret: "secret123", callbackUrl: "callback123", svgIcon: "<svg />")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "brucevoos", password: "p@ssword"),
            to: "/auth-clients/\(authClient.id?.uuidString ?? "")",
            method: .PUT,
            body: authClientToUpdate
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        guard let updatedAuthClient = try? AuthClient.get(uri: "client-for-update-01") else {
            XCTAssert(true, "Auth client was not found")
            return
        }

        XCTAssertEqual(updatedAuthClient.id, authClient.id, "Auth client id should be correct.")
        XCTAssertEqual(updatedAuthClient.name, authClientToUpdate.name, "Auth client name should be correct.")
        XCTAssertEqual(updatedAuthClient.uri, authClientToUpdate.uri, "Auth client uri should be correct.")
        XCTAssertEqual(updatedAuthClient.callbackUrl, authClientToUpdate.callbackUrl, "Auth client callbackUrl should be correct.")
        XCTAssertEqual(updatedAuthClient.clientId, authClientToUpdate.clientId, "Auth client clientId should be correct.")
        XCTAssertEqual(updatedAuthClient.clientSecret, authClientToUpdate.clientSecret, "Auth client secret should be correct.")
    }

    func testAuthClientShouldNotBeUpdatedIfUserIsNotSuperUser() throws {

        // Arrange.
        _ = try User.create(userName: "georgevoos")
        let authClient = try AuthClient.create(type: .apple, name: "Apple", uri: "client-for-update-02", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
        let authClientToUpdate = AuthClientDto(type: .microsoft, name: "Microsoft", uri: "client-for-update-02", tenantId: "123", clientId: "clientId", clientSecret: "secret123", callbackUrl: "callback123", svgIcon: "<svg />")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "georgevoos", password: "p@ssword"),
            to: "/auth-clients/\(authClient.id?.uuidString ?? "")",
            method: .PUT,
            body: authClientToUpdate
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    func testAuthClientShouldNotBeUpdatedIfAuthClientWithSameCodeExists() throws {

        // Arrange.
        let user = try User.create(userName: "samvoos")
        try user.attach(role: "administrator")
        _ = try AuthClient.create(type: .apple, name: "Apple", uri: "client-for-update-03", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
        let authClient02 = try AuthClient.create(type: .apple, name: "Apple", uri: "client-for-update-04", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
        let authClientToUpdate = AuthClientDto(type: .microsoft, name: "Microsoft", uri: "client-for-update-03", tenantId: "123", clientId: "clientId", clientSecret: "secret123", callbackUrl: "callback123", svgIcon: "<svg />")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "samvoos", password: "p@ssword"),
            to: "/auth-clients/\(authClient02.id?.uuidString ?? "")",
            method: .PUT,
            data: authClientToUpdate
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "authClientWithUriExists", "Error code should be equal 'roleWithCodeExists'.")
    }
}

