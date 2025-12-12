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
    
    @Suite("Instance (GET /instance)", .serialized, .tags(.instance))
    struct InstanceReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Instance should be returned for all users`() async throws {
            // Act.
            let instance = try await application.getResponse(
                to: "/instance",
                method: .GET,
                decodeTo: InstanceDto.self
            )
            
            // Assert.
            #expect(instance.title == "Vernissage", "Instance information should be returned.")
        }
    }
}
