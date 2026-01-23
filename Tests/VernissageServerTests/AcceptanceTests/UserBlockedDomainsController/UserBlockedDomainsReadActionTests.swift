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
    
    @Suite("UserBlockedDomains (GET /user-blocked-domains/:id)", .serialized, .tags(.userBlockedDomains))
    struct UserBlockedDomainsReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `User blocked domain should be returned for authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "larachips")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "rude01.com")
            
            // Act.
            let result = try await application.getResponse(
                as: .user(userName: "larachips", password: "p@ssword"),
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .GET,
                decodeTo: UserBlockedDomainDto.self
            )
            
            // Assert.
            #expect(result.id != nil, "User blocked domain should be returned.")
            #expect(result.domain == "rude01.com", "Correct domain should be returned.")
        }
        
        @Test
        func `Forbidden should be returned for getting somebody else blocked domain`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nogochips")
            _ = try await application.createUser(userName: "tenichips")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "rude12.com")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "tenichips", password: "p@ssword"),
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test
        func `Unauthorize should be returned for not authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "yorichips")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "rude13.com")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
