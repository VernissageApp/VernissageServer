//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class InstanceBlockedDomainsUpdateActionTests: CustomTestCase {
    func testInstanceBlockedDomainShouldBeUpdatedByAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "laratobyk")
        try await user.attach(role: Role.moderator)

        let orginalInstanceBlockedDomain = try await InstanceBlockedDomain.create(domain: "rude01.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "rude02.com", reason: "This is spam")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "laratobyk", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            body: instanceBlockedDomainDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be created (200).")
        let instanceBlockedDomain = try await InstanceBlockedDomain.get(domain: "rude02.com")
        XCTAssertEqual(instanceBlockedDomain?.reason, "This is spam", "Reason should be set correctly.")
    }
    
    func testInstanceBlockedDomainShouldNotBeUpdatedIfDomainWasNotSpecified() async throws {

        // Arrange.
        let user = try await User.create(userName: "nikoutobyk")
        try await user.attach(role: Role.moderator)

        let orginalInstanceBlockedDomain = try await InstanceBlockedDomain.create(domain: "rude10.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "", reason: "This is spam")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "nikoutobyk", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            data: instanceBlockedDomainDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("domain"), "is less than minimum of 1 character(s)")
    }

    func testInstanceBlockedDomainShouldNotBeUpdatedIfDomainIsTooLong() async throws {

        // Arrange.
        let user = try await User.create(userName: "henrytobyk")
        try await user.attach(role: Role.moderator)

        let orginalInstanceBlockedDomain = try await InstanceBlockedDomain.create(domain: "rude21.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: String.createRandomString(length: 501))

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "henrytobyk", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            data: instanceBlockedDomainDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("domain"), "is greater than maximum of 500 character(s)")
    }
    
    func testInstanceBlockedDomainShouldNotBeUpdatedIfReasonIsTooLong() async throws {

        // Arrange.
        let user = try await User.create(userName: "gorgetobyk")
        try await user.attach(role: Role.moderator)

        let orginalInstanceBlockedDomain = try await InstanceBlockedDomain.create(domain: "rude11.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "spamiox12.com", reason: String.createRandomString(length: 501))

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "gorgetobyk", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            data: instanceBlockedDomainDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("reason"), "is not null and is greater than maximum of 500 character(s)")
    }

    func testForbiddenShouldBeReturneddForRegularUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "nogotobyk")
        
        let orginalInstanceBlockedDomain = try await InstanceBlockedDomain.create(domain: "rude12.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "rude12a.com", reason: "This is spam")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nogotobyk", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            body: instanceBlockedDomainDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
    }
    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "yoritobyk")

        let orginalInstanceBlockedDomain = try await InstanceBlockedDomain.create(domain: "rude13.com")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "rude13a.com", reason: "This is spam")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .PUT,
            body: instanceBlockedDomainDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
