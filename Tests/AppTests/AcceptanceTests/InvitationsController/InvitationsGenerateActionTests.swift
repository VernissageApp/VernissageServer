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
    
    func testInvitationShouldNotBeGeneratedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/invitations/generate", method: .POST)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
