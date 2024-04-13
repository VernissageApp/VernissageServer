//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class SettingsPublicActionTests: CustomTestCase {
    func testListOfPublicSettingsShouldBeReturnedForNotAuthorized() async throws {

        // Act.
        let settings = try SharedApplication.application().getResponse(
            to: "/settings/public",
            method: .GET,
            decodeTo: PublicSettingsDto.self
        )

        // Assert.
        XCTAssertNotNil(settings, "Public settings should be returned.")
    }
}
