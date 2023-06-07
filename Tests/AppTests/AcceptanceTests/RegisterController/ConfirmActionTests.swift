//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import Fluent

final class ConfirmActionTests: XCTestCase {

    func testAccountShouldBeConfirmedWithCorrectConfirmationGuid() throws {

        // Arrange.
        let user = try User.create(userName: "samanthasmith", emailWasConfirmed: false)
        let confirmEmailRequestDto = ConfirmEmailRequestDto(id: user.id!, confirmationGuid: user.emailConfirmationGuid!)

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/register/confirm", method: .POST, body: confirmEmailRequestDto)

        // Assert.
        let userAfterRequest = try User.get(userName: "samanthasmith")
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        XCTAssertEqual(userAfterRequest.emailWasConfirmed, true, "Email is not confirmed.")
    }

    func testAccountShouldNotBeConfirmedWithIncorrectConfirmationGuid() throws {

        // Arrange.
        let user = try User.create(userName: "eriksmith", emailWasConfirmed: false)
        let confirmEmailRequestDto = ConfirmEmailRequestDto(id: user.id!, confirmationGuid: UUID().uuidString)

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/register/confirm", method: .POST, body: confirmEmailRequestDto)

        // Assert.
        let userAfterRequest = try User.get(userName: "eriksmith")
        XCTAssertEqual(response.status, HTTPResponseStatus.badRequest, "Response http status code should be ok (200).")
        XCTAssertEqual(userAfterRequest.emailWasConfirmed, false, "Email is confirmed.")
    }
}
