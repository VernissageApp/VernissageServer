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

@Suite("GET /", .serialized, .tags(.nodeinfo))
struct NodeInfo2ActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Node info should be returned in correct format")
    func nodeInfoShouldBeReturnedInCorrectFormat() throws {
        
        // Act.
        let nodeInfoDto = try application.getResponse(
            to: "/nodeinfo/2.0",
            version: .v1,
            decodeTo: NodeInfoDto.self
        )
        
        // Assert.
        #expect(nodeInfoDto.version == "2.0", "Property 'version' should conatin protocol version.")
        #expect(nodeInfoDto.openRegistrations == true, "Property 'openRegistrations' should contain link to nodeinfo.")
    }
}

