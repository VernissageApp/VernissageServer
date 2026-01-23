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
    
    @Suite("InstanceBlockedDomains (GET /instance-blocked-domains/:id)", .serialized, .tags(.instanceBlockedDomains))
    struct InstanceBlockedDomainsReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Instance blocked domain should be returned for authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "larawikol")
            try await application.attach(user: user, role: Role.moderator)
            let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "rude61.com")
            
            // Act.
            let result = try await application.getResponse(
                as: .user(userName: "larawikol", password: "p@ssword"),
                to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
                method: .GET,
                decodeTo: InstanceBlockedDomainDto.self
            )
            
            // Assert.
            #expect(result.id != nil, "User blocked domain should be returned.")
            #expect(result.domain == "rude61.com", "Correct domain should be returned.")
        }
        
        @Test
        func `Forbidden should be returned for regular user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogovikowl")
            let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "rude62.com")
                        
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogovikowl", password: "p@ssword"),
                to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test
        func `Unauthorize should be returned for not authorized user`() async throws {
            
            // Arrange.
            let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "rude63.com")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
