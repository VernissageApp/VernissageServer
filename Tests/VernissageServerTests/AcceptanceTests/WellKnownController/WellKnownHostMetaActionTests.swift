//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("WellKnown (GET /.well-known/host-meta)", .serialized, .tags(.wellKnown))
    struct WellKnownHostMetaActionTests {
        
        let xmlContent =
"""
<?xml version="1.0" encoding="UTF-8"?>
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
    <Link rel="lrdd" template="http://localhost:8080/.well-known/webfinger?resource={uri}"/>
</XRD>
"""
        
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Host meta should be returned in correct format")
        func hostMetaShouldBeReturnedInCorrectFormat() throws {
            
            // Act.
            let response = try application.sendRequest(
                to: "/.well-known/host-meta",
                version: .none,
                method: .GET)
            
            // Assert.
            #expect(response.body.string == xmlContent, "Response should return content in correct format.")
            #expect(response.headers.contentType?.description == "application/xrd+xml; charset=utf-8", "Response should return correct content type.")
        }
    }
}
