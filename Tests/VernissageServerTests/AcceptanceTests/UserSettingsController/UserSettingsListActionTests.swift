//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("UserSettings (GET /user-settings)", .serialized, .tags(.userSettings))
    struct UserSettingsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `List of user settings should be returned for authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinvlodim")
            
            _ = try await application.createUserSetting(userId: user.requireID(), key: "note-template", value: "123")
            _ = try await application.createUserSetting(userId: user.requireID(), key: "hashtags-template", value: "#tag")
            
            // Act.
            let userSettings = try await application.getResponse(
                as: .user(userName: "robinvlodim", password: "p@ssword"),
                to: "/user-settings",
                method: .GET,
                decodeTo: [UserSettingDto].self
            )
            
            // Assert.
            #expect(userSettings.count == 2, "Two user settings should be returned")
        }
        
        @Test
        func `List of user settings should not be returned when user is not authorized`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/user-settings", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
