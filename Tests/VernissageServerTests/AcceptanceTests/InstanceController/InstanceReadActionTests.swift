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

extension InstanceControllerTests {
    
    @Suite("GET /", .serialized, .tags(.instance))
    struct InstanceReadActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Instance should be returned for all users")
        func instanceShouldBeReturnedForAllUsers() async throws {
            // Act.
            let instance = try application.getResponse(
                to: "/instance",
                method: .GET,
                decodeTo: InstanceDto.self
            )
            
            // Assert.
            #expect(instance != nil, "Instance information should be returned.")
        }
    }
}
