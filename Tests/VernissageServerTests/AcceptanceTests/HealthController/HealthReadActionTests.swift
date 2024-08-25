//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class HealthReadActionTests: CustomTestCase {
    
    func testHealthStatusShouldBeReturned() async throws {
            
        // Act.
        let healthDto = try SharedApplication.application().getResponse(
            to: "/health",
            decodeTo: HealthDto.self
        )
        
        // Assert.
        XCTAssertNotNil(healthDto, "Healt object have to be returned")
    }
}

