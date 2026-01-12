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
    
    @Suite("UserBlockedDomains (POST /user-blocked-domains)", .serialized, .tags(.userBlockedDomains))
    struct UserBlockedDomainsCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `User blocked domain should be created by authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "laravulop")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: "spamiox01.com", reason: "This is spam")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laravulop", password: "p@ssword"),
                to: "/user-blocked-domains",
                method: .POST,
                body: userBlockedDomainDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let instanceBlockedDomain = try await application.getUserBlockedDomain(domain: "spamiox01.com")
            #expect(instanceBlockedDomain?.reason == "This is spam", "Reason should be set correctly.")
        }
        
        @Test
        func `User blocked domain should not be created if domain was not specified`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nikovulop")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: "", reason: "This is spam")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikovulop", password: "p@ssword"),
                to: "/user-blocked-domains",
                method: .POST,
                data: userBlockedDomainDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("domain") == "is less than minimum of 1 character(s)")
        }
        
        @Test
        func `User blocked domain should not be created if domain is too long`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "robovulop")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: String.createRandomString(length: 501))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robovulop", password: "p@ssword"),
                to: "/user-blocked-domains",
                method: .POST,
                data: userBlockedDomainDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("domain") == "is greater than maximum of 500 character(s)")
        }
        
        @Test
        func `User blocked domain should not be created if reason is too long`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "gorgevulop")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: "spamiox12.com", reason: String.createRandomString(length: 501))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "gorgevulop", password: "p@ssword"),
                to: "/user-blocked-domains",
                method: .POST,
                data: userBlockedDomainDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("reason") == "is not null and is greater than maximum of 500 character(s)")
        }
                
        @Test
        func `Unauthorize should be returnedd for not authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "yorivulop")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: "spamiox03.com", reason: "This is spam")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/user-blocked-domains",
                method: .POST,
                body: userBlockedDomainDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
