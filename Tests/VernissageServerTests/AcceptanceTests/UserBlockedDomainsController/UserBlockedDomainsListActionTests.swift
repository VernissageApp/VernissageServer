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
    
    @Suite("UserBlockedDomains (GET /user-blocked-domains)", .serialized, .tags(.userBlockedDomains))
    struct UserBlockedDomainsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `List of user blocked domains should be returned for user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinfruks")
            _ = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "pornfix1.com")
            _ = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "pornfix2.com")
            
            // Act.
            let domains = try await application.getResponse(
                as: .user(userName: "robinfruks", password: "p@ssword"),
                to: "/user-blocked-domains",
                method: .GET,
                decodeTo: PaginableResultDto<UserBlockedDomainDto>.self
            )
            
            // Assert.
            #expect(domains.data.count > 0, "Some domains should be returned.")
        }
                        
        @Test
        func `List of user blocked domains should not be returned when user is not authorized`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/user-blocked-domains", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
