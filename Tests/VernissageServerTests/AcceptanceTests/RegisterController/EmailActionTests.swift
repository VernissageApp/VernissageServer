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

extension RegisterControllerTests {
    
    @Suite("GET /email/:email", .serialized, .tags(.register))
    struct EmailActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Email validation should return true if email exists")
        func emailValidationShouldReturnTrueIfEmailExists() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "tomsmith")
            
            // Act.
            let booleanResponseDto = try application.getResponse(
                to: "/register/email/tomsmith@testemail.com",
                decodeTo: BooleanResponseDto.self)
            
            // Assert.
            #expect(booleanResponseDto.result, "Server should return true for email: tomsmith@testemail.com.")
        }
        
        @Test("Email validation should return false if email not exists")
        func emailValidationShouldReturnFalseIfEmailNotExists() throws {
            
            // Arrange.
            let url = "/register/email/notexists@testemail.com"
            
            // Act.
            let booleanResponseDto = try application.getResponse(to: url, decodeTo: BooleanResponseDto.self)
            
            // Assert.
            #expect(booleanResponseDto.result == false, "Server should return false for email: notexists@testemail.com.")
        }
    }
}
