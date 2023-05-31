@testable import App
import XCTest
import XCTVapor

final class AuthenticationClientsReadActionTests: XCTestCase {

    func testAuthClientShouldBeReturnedForSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "robinwath")
        try user.attach(role: "administrator")
        let authClient = try AuthClient.create(type: .apple, name: "Apple", uri: "client-for-read-01", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")

        // Act.
        let authClientDto = try SharedApplication.application().getResponse(
            as: .user(userName: "robinwath", password: "p@ssword"),
            to: "/auth-clients/\(authClient.id?.uuidString ?? "")",
            method: .GET,
            decodeTo: AuthClientDto.self
        )

        // Assert.
        XCTAssertEqual(authClientDto.id, authClient.id, "Auth client id should be correct.")
        XCTAssertEqual(authClientDto.name, authClient.name, "Auth client name should be correct.")
        XCTAssertEqual(authClientDto.uri, authClient.uri, "Auth client uri should be correct.")
        XCTAssertEqual(authClientDto.callbackUrl, authClient.callbackUrl, "Auth client callbackUrl should be correct.")
        XCTAssertEqual(authClientDto.clientId, authClient.clientId, "Auth client clientId should be correct.")
        XCTAssertEqual(authClientDto.clientSecret, "", "Auth client secret should be empty.")
    }

    func testAuthClientShouldBeReturnedIfUserIsNotSuperUser() throws {

        // Arrange.
        _ = try User.create(userName: "rickywath")
        let authClient = try AuthClient.create(type: .apple, name: "Apple", uri: "client-for-read-02", tenantId: "tenantId", clientId: "clientId", clientSecret: "rickywath", callbackUrl: "callback", svgIcon: "svg")

        // Act.
        let authClientDto = try SharedApplication.application().getResponse(
            as: .user(userName: "robinwath", password: "p@ssword"),
            to: "/auth-clients/\(authClient.id?.uuidString ?? "")",
            method: .GET,
            decodeTo: AuthClientDto.self
        )

        // Assert.
        XCTAssertEqual(authClientDto.id, authClient.id, "Auth client id should be correct.")
        XCTAssertEqual(authClientDto.name, authClient.name, "Auth client name should be correct.")
        XCTAssertEqual(authClientDto.uri, authClient.uri, "Auth client uri should be correct.")
        XCTAssertEqual(authClientDto.callbackUrl, authClient.callbackUrl, "Auth client callbackUrl should be correct.")
        XCTAssertEqual(authClientDto.clientId, authClient.clientId, "Auth client clientId should be correct.")
        XCTAssertEqual(authClientDto.clientSecret, "", "Auth client secret should be empty.")
    }

    func testCorrectStatusCodeShouldBeReturnedIdAuthClientNotExists() throws {

        // Arrange.
        let user = try User.create(userName: "tedwarth")
        try user.attach(role: "administrator")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "tedwarth", password: "p@ssword"),
            to: "/auth-clients/\(UUID().uuidString)",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
