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
    
    @Suite("Register (GET /register/username/:username)", .serialized, .tags(.register))
    struct UserNameActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `User name validation should return true if userName exists`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "johndoe")
            
            // Act.
            let booleanResponseDto = try await application.getResponse(
                to: "/register/username/johndoe",
                decodeTo: BooleanResponseDto.self)
            
            // Assert.
            #expect(booleanResponseDto.result, "Server should return true for username: johndoe.")
        }
        
        @Test
        func `User name validation should return false if userName not exists`() async throws {
            
            // Arrange.
            let url = "/register/username/notexists"
            
            // Act.
            let booleanResponseDto = try await application.getResponse(to: url, decodeTo: BooleanResponseDto.self)
            
            // Assert.
            #expect(booleanResponseDto.result == false, "Server should return false for username: notexists.")
        }
    }
}
