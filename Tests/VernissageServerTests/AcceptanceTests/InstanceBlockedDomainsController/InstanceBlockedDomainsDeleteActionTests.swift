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

@Suite("DELETE /", .serialized, .tags(.instanceBlockedDomains))
struct InstanceBlockedDomainsDeleteActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Instance blocked domain should be deleted by authorized user")
    func instanceBlockedDomainShouldBeDeletedByAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await application.createUser(userName: "laragibro")
        try await application.attach(user: user, role: Role.moderator)

        let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "stupid01.com")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "laragibro", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
        let instanceBlockedDomain = try await application.getInstanceBlockedDomain(domain: "stupid01.com")
        #expect(instanceBlockedDomain == nil, "Instance blocked domain should be deleted.")
    }
    
    @Test("Forbidden should be returned for regular user")
    func forbiddenShouldBeReturneddForRegularUser() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "nogogibro")
        let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "stupid02.com")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "nogogibro", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
    }
    
    @Test("Unauthorize should be returned for not authorized user")
    func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "yorigibro")
        let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "stupid03.com")
        
        // Act.
        let response = try application.sendRequest(
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
