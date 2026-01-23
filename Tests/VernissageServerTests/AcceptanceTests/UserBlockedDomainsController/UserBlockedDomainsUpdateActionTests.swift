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
    
    @Suite("UserBlockedDomains (PUT /user-blocked-domains/:id)", .serialized, .tags(.userBlockedDomains))
    struct UserBlockedDomainsUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `User blocked domain should be updated by authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "larafionik")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "rude01.com")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: "rude02.com", reason: "This is spam")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "larafionik", password: "p@ssword"),
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .PUT,
                body: userBlockedDomainDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let userBlockedDomain = try await application.getUserBlockedDomain(domain: "rude02.com")
            #expect(userBlockedDomain?.reason == "This is spam", "Reason should be set correctly.")
        }
        
        @Test
        func `User blocked domain should be updated with lower case only`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "witoldfionik")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "RUDEXXX001.com")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: "RUDEXXX002.com", reason: "This is spam")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "witoldfionik", password: "p@ssword"),
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .PUT,
                body: userBlockedDomainDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let userBlockedDomain = try await application.getUserBlockedDomain(id: orginalUserBlockedDomain.requireID())
            #expect(userBlockedDomain?.domain == "rudexxx002.com", "Reason should be set correctly.")
        }
        
        @Test
        func `User blocked domain should not be updated if domain was not specified`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikoufionik")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "rude10.com")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: "", reason: "This is spam")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikoufionik", password: "p@ssword"),
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .PUT,
                data: userBlockedDomainDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("domain") == "is less than minimum of 1 character(s)")
        }
        
        @Test
        func `User blocked domain should not be updated if domain is too long`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "henryfionik")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "rude21.com")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: String.createRandomString(length: 501))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "henryfionik", password: "p@ssword"),
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .PUT,
                data: userBlockedDomainDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("domain") == "is greater than maximum of 500 character(s)")
        }
        
        @Test
        func `User blocked domain should not be updated if reason is too long`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "gorgefionik")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "rude11.com")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: "spamiox12.com", reason: String.createRandomString(length: 501))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "gorgefionik", password: "p@ssword"),
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .PUT,
                data: userBlockedDomainDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("reason") == "is not null and is greater than maximum of 500 character(s)")
        }
        
        @Test
        func `Forbidden should be returned for updating somebody else blocked domain`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nogofionik")
            _ = try await application.createUser(userName: "tenifionik")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "rude12.com")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: "rude12a.com", reason: "This is spam")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "tenifionik", password: "p@ssword"),
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .PUT,
                body: userBlockedDomainDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test
        func `Unauthorize should be returned for not authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "yorifionik")
            let orginalUserBlockedDomain = try await application.createUserBlockedDomain(userId: user.requireID(), domain: "rude13.com")
            let userBlockedDomainDto = UserBlockedDomainDto(domain: "rude13a.com", reason: "This is spam")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/user-blocked-domains/" + (orginalUserBlockedDomain.stringId() ?? ""),
                method: .PUT,
                body: userBlockedDomainDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
