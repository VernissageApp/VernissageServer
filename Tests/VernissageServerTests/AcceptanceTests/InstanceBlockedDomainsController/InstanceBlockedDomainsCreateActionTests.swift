//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class InstanceBlockedDomainsCreateActionTests: CustomTestCase {
    func testInstanceBlockedDomainShouldBeCreatedByAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "larautopix")
        try await user.attach(role: Role.moderator)

        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "spamiox01.com", reason: "This is spam")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "larautopix", password: "p@ssword"),
            to: "/instance-blocked-domains",
            method: .POST,
            body: instanceBlockedDomainDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.created, "Response http status code should be created (201).")
        let instanceBlockedDomain = try await InstanceBlockedDomain.get(domain: "spamiox01.com")
        XCTAssertEqual(instanceBlockedDomain?.reason, "This is spam", "Reason should be set correctly.")
    }
    
    func testInstanceBlockedDomainShouldNotBeCreatedIfDomainWasNotSpecified() async throws {

        // Arrange.
        let user = try await User.create(userName: "nikoutopix")
        try await user.attach(role: Role.moderator)

        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "", reason: "This is spam")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "nikoutopix", password: "p@ssword"),
            to: "/instance-blocked-domains",
            method: .POST,
            data: instanceBlockedDomainDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("domain"), "is less than minimum of 1 character(s)")
    }

    func testInstanceBlockedDomainShouldNotBeCreatedIfDomainIsTooLong() async throws {

        // Arrange.
        let user = try await User.create(userName: "robotutopix")
        try await user.attach(role: Role.moderator)

        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: String.createRandomString(length: 501))

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "robotutopix", password: "p@ssword"),
            to: "/instance-blocked-domains",
            method: .POST,
            data: instanceBlockedDomainDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("domain"), "is greater than maximum of 500 character(s)")
    }
    
    func testInstanceBlockedDomainShouldNotBeCreatedIfReasonIsTooLong() async throws {

        // Arrange.
        let user = try await User.create(userName: "gorgeutopix")
        try await user.attach(role: Role.moderator)

        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "spamiox12.com", reason: String.createRandomString(length: 501))

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "gorgeutopix", password: "p@ssword"),
            to: "/instance-blocked-domains",
            method: .POST,
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
        _ = try await User.create(userName: "nogoutopix")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "spamiox02.com", reason: "This is spam")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nogoutopix", password: "p@ssword"),
            to: "/instance-blocked-domains",
            method: .POST,
            body: instanceBlockedDomainDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
    }
    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "yoriutopix")
        let instanceBlockedDomainDto = InstanceBlockedDomainDto(domain: "spamiox03.com", reason: "This is spam")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/instance-blocked-domains",
            method: .POST,
            body: instanceBlockedDomainDto
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
