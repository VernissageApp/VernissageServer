//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class WellKnownHostMetaActionTests: CustomTestCase {
    
    let xmlContent =
"""
<?xml version="1.0" encoding="UTF-8"?>
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
    <Link rel="lrdd" template="http://localhost:8080/.well-known/webfinger?resource={uri}"/>
</XRD>
"""
    
    func testHostMetaShouldBeReturnedInCorrectFormat() throws {
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/.well-known/host-meta",
            version: .none,
            method: .GET)
        
        // Assert.
        XCTAssertEqual(response.body.string, xmlContent, "Response should return content in correct format.")
        XCTAssertEqual(response.headers.contentType?.description, "application/xrd+xml; charset=utf-8", "Response should return correct content type.")
    }
}
