//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class WellKnownNodeInfoActionTests: CustomTestCase {
    
    func testNodeInfoShouldBeReturnedInCorrectFormat() throws {
        
        // Act.
        let nodeInfoLinkDto = try SharedApplication.application().getResponse(
            to: "/.well-known/nodeinfo",
            version: .none,
            decodeTo: NodeInfoLinkDto.self
        )
        
        // Assert.
        XCTAssertEqual(nodeInfoLinkDto.rel, "http://nodeinfo.diaspora.software/ns/schema/2.0", "Property 'rel' should conatin protocol version.")
        XCTAssertEqual(nodeInfoLinkDto.href, "http://localhost:8080/api/v1/nodeinfo/2.0", "Property 'href' should contain link to nodeinfo.")
    }
}

