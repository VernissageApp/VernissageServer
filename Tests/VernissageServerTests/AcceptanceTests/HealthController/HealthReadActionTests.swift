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

extension HealthControllerTests {
    
    @Suite("GET /", .serialized, .tags(.health))
    struct HealthReadActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Health status should be returned")
        func healthStatusShouldBeReturned() async throws {
            
            // Act.
            let healthDto = try application.getResponse(
                to: "/health",
                decodeTo: HealthDto.self
            )
            
            // Assert.
            #expect(healthDto != nil, "Healt object have to be returned")
        }
    }
}
