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

@Suite("PUT /:id", .serialized, .tags(.instanceBlockedDomains))
struct InstanceBlockedDomainsUpdateActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Instance blocked domain should be updated by authorized user")
    func instanceBlockedDomainShouldBeUpdatedByAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await application.createUser(userName: "laratobyk")
        try await application.attach(user: user, role: Role.moderator)

        let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "rude01.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "rude02.com", reason: "This is spam")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "laratobyk", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            body: instanceBlockedDomainDto
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
        let instanceBlockedDomain = try await application.getInstanceBlockedDomain(domain: "rude02.com")
        #expect(instanceBlockedDomain?.reason == "This is spam", "Reason should be set correctly.")
    }
    
    @Test("Instance blocked domain should not be updated if domain was not specified")
    func instanceBlockedDomainShouldNotBeUpdatedIfDomainWasNotSpecified() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "nikoutobyk")
        try await application.attach(user: user, role: Role.moderator)

        let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "rude10.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "", reason: "This is spam")

        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "nikoutobyk", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            data: instanceBlockedDomainDto
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("domain") == "is less than minimum of 1 character(s)")
    }

    @Test("Instance blocked domain should not be updated if domain is too long")
    func instanceBlockedDomainShouldNotBeUpdatedIfDomainIsTooLong() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "henrytobyk")
        try await application.attach(user: user, role: Role.moderator)

        let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "rude21.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: String.createRandomString(length: 501))

        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "henrytobyk", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            data: instanceBlockedDomainDto
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("domain") == "is greater than maximum of 500 character(s)")
    }
    
    @Test("Instance blocked domain should not be updated if reason is too long")
    func instanceBlockedDomainShouldNotBeUpdatedIfReasonIsTooLong() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "gorgetobyk")
        try await application.attach(user: user, role: Role.moderator)

        let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "rude11.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "spamiox12.com", reason: String.createRandomString(length: 501))

        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "gorgetobyk", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            data: instanceBlockedDomainDto
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        #expect(errorResponse.error.reason == "Validation errors occurs.")
        #expect(errorResponse.error.failures?.getFailure("reason") == "is not null and is greater than maximum of 500 character(s)")
    }

    @Test("Forbidden should be returned for regular user")
    func forbiddenShouldBeReturneddForRegularUser() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "nogotobyk")
        
        let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "rude12.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "rude12a.com", reason: "This is spam")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "nogotobyk", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            body: instanceBlockedDomainDto
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
    }
    
    @Test("Unauthorize should be returned for not authorized user")
    func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "yoritobyk")

        let orginalInstanceBlockedDomain = try await application.createInstanceBlockedDomain(domain: "rude13.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "rude13a.com", reason: "This is spam")
        
        // Act.
        let response = try application.sendRequest(
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            body: instanceBlockedDomainDto
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
