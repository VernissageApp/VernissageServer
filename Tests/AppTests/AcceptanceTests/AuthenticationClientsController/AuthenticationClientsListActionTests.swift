@testable import App
import XCTest
import XCTVapor

final class AuthenticationClientsListActionTests: XCTestCase {

    func testListOfAuthClientsShouldBeReturnedForSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "robintorx")
        try user.attach(role: "administrator")
        _ = try AuthClient.create(type: .apple, name: "Apple", uri: "client-for-list-01", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
        _ = try AuthClient.create(type: .apple, name: "Apple", uri: "client-for-list-02", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")

        // Act.
        let authClients = try SharedApplication.application().getResponse(
            as: .user(userName: "robintorx", password: "p@ssword"),
            to: "/auth-clients",
            method: .GET,
            decodeTo: [AuthClientDto].self
        )

        // Assert.
        XCTAssert(authClients.count > 0, "A list of auth clients was not returned.")
    }

    func testListOfAuthClientsShouldBeReturnedForNotSuperUser() throws {

        // Arrange.
        _ = try User.create(userName: "wictortorx")
        _ = try AuthClient.create(type: .apple, name: "Apple", uri: "client-for-list-03", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
        _ = try AuthClient.create(type: .apple, name: "Apple", uri: "client-for-list-04", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")

        // Act.
        let authClients = try SharedApplication.application().getResponse(
            as: .user(userName: "wictortorx", password: "p@ssword"),
            to: "/auth-clients",
            method: .GET,
            decodeTo: [AuthClientDto].self
        )

        // Assert.
        XCTAssert(authClients.count > 0, "A list of auth clients was not returned.")
    }
}
