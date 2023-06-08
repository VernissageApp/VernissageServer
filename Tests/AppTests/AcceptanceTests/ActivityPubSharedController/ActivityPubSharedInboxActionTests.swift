//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class ActivityPubSharedInboxActionTests: CustomTestCase {
    
    func testInboxShouldReturnOkAfterRecivingMessage() throws {

        // Arrange.
        let roleDto = RoleDto(code: "reviewer", title: "Reviewer", description: "Code reviewers")

        // Act.        
        let response = try SharedApplication.application().sendRequest(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: .init(),
            data: roleDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }
}

