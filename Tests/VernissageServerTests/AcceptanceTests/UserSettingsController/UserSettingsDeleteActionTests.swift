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
    
    @Suite("UserSettings (DELETE /user-settings/:key)", .serialized, .tags(.userSettings))
    struct UserSettingsDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User setting should be deleted for authorized user")
        func userSettingShouldBeDeletedForAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robingrebinor")
            _ = try await application.createUserSetting(userId: user.requireID(), key: "note-template", value: "123")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "robingrebinor", password: "p@ssword"),
                to: "/user-settings/note-template",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userSettings = try await application.getAllUserSettings(userId: user.requireID())
            #expect(userSettings.isEmpty, "User settings should be empty.")
        }
        
        @Test("User settings should not be deleted when user is not authorized")
        func userSettingsShouldNotBeDeletedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/user-settings/test-key", method: .DELETE)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
