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

extension InstanceBlockedDomainsControllerTests {
    
    @Suite("POST /", .serialized, .tags(.instanceBlockedDomains))
    struct InstanceBlockedDomainsCreateActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Instance blocked domain should be created by authorized user")
        func instanceBlockedDomainShouldBeCreatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "larautopix")
            try await application.attach(user: user, role: Role.moderator)
            
            let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "spamiox01.com", reason: "This is spam")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "larautopix", password: "p@ssword"),
                to: "/instance-blocked-domains",
                method: .POST,
                body: instanceBlockedDomainDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let instanceBlockedDomain = try await application.getInstanceBlockedDomain(domain: "spamiox01.com")
            #expect(instanceBlockedDomain?.reason == "This is spam", "Reason should be set correctly.")
        }
        
        @Test("Instance blocked domain should not be created if domain was not specified")
        func instanceBlockedDomainShouldNotBeCreatedIfDomainWasNotSpecified() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikoutopix")
            try await application.attach(user: user, role: Role.moderator)
            
            let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "", reason: "This is spam")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "nikoutopix", password: "p@ssword"),
                to: "/instance-blocked-domains",
                method: .POST,
                data: instanceBlockedDomainDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("domain") == "is less than minimum of 1 character(s)")
        }
        
        @Test("Instance blocked domain should not be created if domain is too long")
        func instanceBlockedDomainShouldNotBeCreatedIfDomainIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robotutopix")
            try await application.attach(user: user, role: Role.moderator)
            
            let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: String.createRandomString(length: 501))
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "robotutopix", password: "p@ssword"),
                to: "/instance-blocked-domains",
                method: .POST,
                data: instanceBlockedDomainDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("domain") == "is greater than maximum of 500 character(s)")
        }
        
        @Test("Instance blocked domain should not be created if reason is too long")
        func instanceBlockedDomainShouldNotBeCreatedIfReasonIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "gorgeutopix")
            try await application.attach(user: user, role: Role.moderator)
            
            let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "spamiox12.com", reason: String.createRandomString(length: 501))
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "gorgeutopix", password: "p@ssword"),
                to: "/instance-blocked-domains",
                method: .POST,
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
            _ = try await application.createUser(userName: "nogoutopix")
            let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "spamiox02.com", reason: "This is spam")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "nogoutopix", password: "p@ssword"),
                to: "/instance-blocked-domains",
                method: .POST,
                body: instanceBlockedDomainDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "yoriutopix")
            let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "spamiox03.com", reason: "This is spam")
            
            // Act.
            let response = try application.sendRequest(
                to: "/instance-blocked-domains",
                method: .POST,
                body: instanceBlockedDomainDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
