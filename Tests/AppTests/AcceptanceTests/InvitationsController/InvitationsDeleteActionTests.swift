//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class InvitationsDeleteActionTests: CustomTestCase {
    func testInvitationShouldBeDeletedForAuthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robintermit")
        let invitation = try await Invitation.create(userId: user.requireID())

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "robintermit", password: "p@ssword"),
            to: "/invitations/\(invitation.stringId() ?? "")",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let invitations = try await Invitation.getAll(userId: user.requireID())
        XCTAssertEqual(invitations.count, 0, "Invitation should be deleted")
    }
    
    func testInvitationShouldNotBeDeletedForOtherAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "martintermit")
        _ = try await User.create(userName: "christermit")
        let invitation = try await Invitation.create(userId: user1.requireID())

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "christermit", password: "p@ssword"),
            to: "/invitations/\(invitation.stringId() ?? "")",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testInvitationShouldNotBeGeneratedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/invitations/123", method: .DELETE)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
