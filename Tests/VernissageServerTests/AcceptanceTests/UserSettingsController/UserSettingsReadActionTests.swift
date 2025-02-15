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
    
    @Suite("UserSettings (GET /user-settings/:key)", .serialized, .tags(.userSettings))
    struct UserSettingsReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User setting should be returned for authorized user")
        func userSettingShouldBeReturnedForAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robingreopo")
            _ = try await application.createUserSetting(userId: user.requireID(), key: "note-template", value: "123")
            
            // Act.
            let userSetting = try application.getResponse(
                as: .user(userName: "robingreopo", password: "p@ssword"),
                to: "/user-settings/note-template",
                method: .GET,
                decodeTo: UserSettingDto.self
            )
            
            // Assert.
            #expect(userSetting != nil, "User settings should be returned.")
            #expect(userSetting.value == "123", "Correct value should be returned.")
        }
        
        @Test("User settings should not be returned when user is not authorized")
        func userSettingsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try application.sendRequest(to: "/user-settings/note-template", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
