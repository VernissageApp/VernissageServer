//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class InstanceReadActionTests: CustomTestCase {
    
    func testInstanceShouldBeReturnedForAllUsers() async throws {
        // Act.
        let instance = try SharedApplication.application().getResponse(
            to: "/instance",
            method: .GET,
            decodeTo: InstanceDto.self
        )

        // Assert.
        XCTAssertNotNil(instance, "Instance information should be returned.")
    }
}

