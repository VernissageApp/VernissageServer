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
    
    @Suite("WellKnown (GET /.well-known/nodeinfo)", .serialized, .tags(.wellKnown))
    struct WellKnownNodeInfoActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Node info should be returned in correct format")
        func nodeInfoShouldBeReturnedInCorrectFormat() throws {
            
            // Act.
            let nodeInfoLinkDto = try application.getResponse(
                to: "/.well-known/nodeinfo",
                version: .none,
                decodeTo: NodeInfoLinkDto.self
            )
            
            // Assert.
            #expect(nodeInfoLinkDto.rel == "http://nodeinfo.diaspora.software/ns/schema/2.0", "Property 'rel' should conatin protocol version.")
            #expect(nodeInfoLinkDto.href == "http://localhost:8080/api/v1/nodeinfo/2.0", "Property 'href' should contain link to nodeinfo.")
        }
    }
}
