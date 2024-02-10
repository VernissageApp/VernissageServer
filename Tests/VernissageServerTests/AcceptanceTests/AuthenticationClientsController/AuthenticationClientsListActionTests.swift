//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class AuthenticationClientsListActionTests: CustomTestCase {

    func testListOfAuthClientsShouldBeReturnedForSuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robintorx")
        try await user.attach(role: Role.administrator)
        _ = try await AuthClient.create(type: .apple, name: "Apple", uri: "client-for-list-01", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
        _ = try await AuthClient.create(type: .apple, name: "Apple", uri: "client-for-list-02", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")

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

    func testListOfAuthClientsShouldBeReturnedForNotSuperUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "wictortorx")
        _ = try await AuthClient.create(type: .apple, name: "Apple", uri: "client-for-list-03", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")
        _ = try await AuthClient.create(type: .apple, name: "Apple", uri: "client-for-list-04", tenantId: "tenantId", clientId: "clientId", clientSecret: "secret", callbackUrl: "callback", svgIcon: "svg")

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
