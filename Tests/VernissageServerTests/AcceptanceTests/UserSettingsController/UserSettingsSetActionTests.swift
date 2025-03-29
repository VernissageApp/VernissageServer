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
    
    @Suite("UserSettings (PUT /user-settings)", .serialized, .tags(.userSettings))
    struct UserSettingsSetActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User setting should be saved for authorized user")
        func userSettingShouldBeSavedForAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robingolopen")
            let userSettingDto = UserSettingDto(key: "test-setting", value: "Setting from test")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "robingolopen", password: "p@ssword"),
                to: "/user-settings",
                method: .PUT,
                body: userSettingDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userSettings = try await application.getAllUserSettings(userId: user.requireID())
            #expect(userSettings.contains(where: { $0.key == "test-setting" }), "User setting (key) should be saved.")
            #expect(userSettings.contains(where: { $0.value == "Setting from test" }), "User setting (value) should be saved.")
        }
        
        @Test("User settings should not be saved when user is not authorized")
        func userSettingsShouldNotBeSavedWhenUserIsNotAuthorized() async throws {
            // Arrange.
            let userSettingDto = UserSettingDto(key: "test-setting", value: "Setting from test")
            
            // Act.
            let response = try await application.sendRequest(to: "/user-settings", method: .PUT, body: userSettingDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
