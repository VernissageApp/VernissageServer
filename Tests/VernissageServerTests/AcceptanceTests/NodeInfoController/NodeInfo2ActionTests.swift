//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class NodeInfo2ActionTests: CustomTestCase {
    
    func testNodeInfoShouldBeReturnedInCorrectFormat() throws {
        
        // Act.
        let nodeInfoDto = try SharedApplication.application().getResponse(
            to: "/nodeinfo/2.0",
            version: .v1,
            decodeTo: NodeInfoDto.self
        )
        
        // Assert.
        XCTAssertEqual(nodeInfoDto.version, "2.0", "Property 'version' should conatin protocol version.")
        XCTAssertEqual(nodeInfoDto.openRegistrations, true, "Property 'openRegistrations' should contain link to nodeinfo.")
    }
}

