//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class InvitationsListActionTests: CustomTestCase {
    func testListOfInvitationsShouldBeReturnedForAuthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robingobix")

        _ = try await Invitation.create(userId: user.requireID())
        _ = try await Invitation.create(userId: user.requireID())
        
        // Act.
        let invitations = try SharedApplication.application().getResponse(
            as: .user(userName: "robingobix", password: "p@ssword"),
            to: "/invitations",
            method: .GET,
            decodeTo: [InvitationDto].self
        )

        // Assert.
        XCTAssertNotNil(invitations, "Invitations should be returned.")
        XCTAssertEqual(invitations.count, 2, "Two invitations should be returned")
    }
    
    func testListOfInvitationsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/invitations", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
