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
    
    @Suite("Health (GET /health)", .serialized, .tags(.health))
    struct HealthReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Health status should be returned")
        func healthStatusShouldBeReturned() async throws {
            
            // Act.
            let healthDto = try? await application.getResponse(
                to: "/health",
                decodeTo: HealthDto.self
            )
            
            // Assert.
            #expect(healthDto != nil, "Healt object have to be returned")
        }
    }
}
