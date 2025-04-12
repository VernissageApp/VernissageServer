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
    
    @Suite("InstanceBlockedDomains (GET /instance-blocked-domains)", .serialized, .tags(.instanceBlockedDomains))
    struct InstanceBlockedDomainsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of instance blocked domains should be returned for moderator user")
        func listOfInstanceBlockedDomainsShouldBeReturnedForModeratorUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinborin")
            try await application.attach(user: user, role: Role.moderator)
            
            _ = try await application.createInstanceBlockedDomain(domain: "pornfix1.com")
            _ = try await application.createInstanceBlockedDomain(domain: "pornfix2.com")
            
            // Act.
            let domains = try await application.getResponse(
                as: .user(userName: "robinborin", password: "p@ssword"),
                to: "/instance-blocked-domains",
                method: .GET,
                decodeTo: PaginableResultDto<InstanceBlockedDomainDto>.self
            )
            
            // Assert.
            #expect(domains.data.count > 0, "Some domains should be returned.")
        }
        
        @Test("List of instance blocked domains should be returned for administrator user")
        func listOfInstanceBlockedDomainsShouldBeReturnedForAdministratorUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "wikiborin")
            try await application.attach(user: user1, role: Role.administrator)
            
            _ = try await application.createInstanceBlockedDomain(domain: "pornfix3.com")
            _ = try await application.createInstanceBlockedDomain(domain: "pornfix4.com")
            
            // Act.
            let domains = try await application.getResponse(
                as: .user(userName: "wikiborin", password: "p@ssword"),
                to: "/instance-blocked-domains",
                method: .GET,
                decodeTo: PaginableResultDto<InstanceBlockedDomainDto>.self
            )
            
            // Assert.
            #expect(domains.data.count > 0, "Some domains should be returned.")
        }
        
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldbeReturnedForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "trelborin")
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "trelborin", password: "p@ssword"),
                to: "/instance-blocked-domains",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("List of instance blocked domains should not be returned when user is not authorized")
        func listOfInstanceBlockedDomainsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/instance-blocked-domains", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
