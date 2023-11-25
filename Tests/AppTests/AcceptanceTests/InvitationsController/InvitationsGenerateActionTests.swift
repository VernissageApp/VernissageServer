//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class InvitationsGenerateActionTests: CustomTestCase {
    func testInvitationShouldBeGeneratedForAuthorizedUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "robinfrux")
        
        // Act.
        let invitation = try SharedApplication.application().getResponse(
            as: .user(userName: "robinfrux", password: "p@ssword"),
            to: "/invitations/generate",
            method: .POST,
            decodeTo: InvitationDto.self
        )

        // Assert.
        XCTAssertNotNil(invitation, "Invitation should be generated.")
    }
    
    func testInvitationShouldNtBeGeneratedWhenMaximumNumberOfInvitationHasBeenGenerated() async throws {

        // Arrange.
        let user = try await User.create(userName: "georgefrux")
        _ = try await Invitation.create(userId: user.requireID())
        _ = try await Invitation.create(userId: user.requireID())
        _ = try await Invitation.create(userId: user.requireID())
        _ = try await Invitation.create(userId: user.requireID())
        _ = try await Invitation.create(userId: user.requireID())
        _ = try await Invitation.create(userId: user.requireID())
        _ = try await Invitation.create(userId: user.requireID())
        _ = try await Invitation.create(userId: user.requireID())
        _ = try await Invitation.create(userId: user.requireID())
        _ = try await Invitation.create(userId: user.requireID())
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "georgefrux", password: "p@ssword"),
            to: "/invitations/generate",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "maximumNumberOfInvitationsGenerated", "Error code should be equal 'maximumNumberOfInvitationsGenerated'.")
    }
    
    func testInvitationShouldNotBeGeneratedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/invitations/generate", method: .POST)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
