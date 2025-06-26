//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Vapor
import Testing

extension ControllersTests {

    @Suite("Account (POST /account/email/verified)", .serialized, .tags(.account))
    struct EmailVerifiedActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test("False should be returned when email has not been confirmed")
        func falseShouldBeReturnedWhenEmailHasNotBeenConfirmed() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "samanthatopiqs", emailWasConfirmed: false)
            
            // Act.
            let response = try await application.getResponse(
                as: .user(userName: "samanthatopiqs", password: "p@ssword"),
                to: "/account/email/verified",
                method: .GET,
                decodeTo: BooleanResponseDto.self)
            
            // Assert.
            #expect(response.result == false, "False should be returned when email has not been confirmed.")
        }
        
        @Test("True should be returned when email has not been confirmed")
        func trueShouldBeReturnedWhenEmailHasNotBeenConfirmed() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "eriktopiqs", emailWasConfirmed: true)
            
            // Act.
            let response = try await application.getResponse(
                as: .user(userName: "eriktopiqs", password: "p@ssword"),
                to: "/account/email/verified",
                method: .GET,
                decodeTo: BooleanResponseDto.self)
            
            // Assert.
            #expect(response.result == true, "True should be returned when email has not been confirmed.")
        }
    }
}
