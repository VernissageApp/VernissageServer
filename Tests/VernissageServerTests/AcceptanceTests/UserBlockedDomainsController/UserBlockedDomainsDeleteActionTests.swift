//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("UserBlockedDomainsControllerTests (DELETE /user-blocked-domains/:id)", .serialized, .tags(.userBlockedDomains))
    struct UserBlockedDomainsDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `User blocked domain should be deleted by authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laragecol")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "stupid01.com")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laragecol", password: "p@ssword"),
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let userBlockedDomain = try await application.getUserBlockedDomain(domain: "stupid01.com")
            #expect(userBlockedDomain == nil, "User blocked domain should be deleted.")
        }
        
        @Test
        func `Forbidden should be returned when deleting somebody else domain block`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nogogecol")
            _ = try await application.createUser(userName: "greggecol")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "stupid02.com")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "greggecol", password: "p@ssword"),
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test
        func `Unauthorize should be returned for not authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "yorigecol")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "stupid03.com")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
