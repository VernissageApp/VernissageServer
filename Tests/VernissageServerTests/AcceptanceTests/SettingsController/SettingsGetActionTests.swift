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
    
    @Suite("Settings (GET /settings)", .serialized, .tags(.settings))
    struct SettingsGetActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of settings should be returned for super user")
        func listOfSettingsShouldBeReturnedForSuperUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robingrick")
            try await application.attach(user: user, role: Role.administrator)
            
            // Act.
            let settings = try await application.getResponse(
                as: .user(userName: "robingrick", password: "p@ssword"),
                to: "/settings",
                method: .GET,
                decodeTo: SettingsDto.self
            )
            
            // Assert.
            #expect(settings.webTitle.count > 0, "Settings should be returned.")
        }
        
        @Test("List of settings should not be returned for not super user")
        func listOfSettingsShouldNotBeReturnedForNotSuperUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "wictorgrick")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "wictorgrick", password: "p@ssword"),
                to: "/settings",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("List of settings should not be returned when user is not authorized")
        func listOfSettingsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/settings", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
