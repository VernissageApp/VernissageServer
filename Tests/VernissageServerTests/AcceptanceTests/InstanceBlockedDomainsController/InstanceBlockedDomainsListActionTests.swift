//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class InstanceBlockedDomainsListActionTests: CustomTestCase {
    func testListOfInstanceBlockedDomainsShouldBeReturnedForModeratorUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robinborin")
        try await user.attach(role: Role.moderator)
        
        _ = try await InstanceBlockedDomain.create(domain: "pornfix1.com")
        _ = try await InstanceBlockedDomain.create(domain: "pornfix2.com")
        
        // Act.
        let domains = try SharedApplication.application().getResponse(
            as: .user(userName: "robinborin", password: "p@ssword"),
            to: "/instance-blocked-domains",
            method: .GET,
            decodeTo: PaginableResultDto<InstanceBlockedDomainDto>.self
        )

        // Assert.
        XCTAssertNotNil(domains, "Instance blocked domains should be returned.")
        XCTAssertTrue(domains.data.count > 0, "Some domains should be returned.")
    }
    
    func testListOfInstanceBlockedDomainsShouldBeReturnedForAdministratorUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "wikiborin")
        try await user1.attach(role: Role.administrator)
        
        _ = try await InstanceBlockedDomain.create(domain: "pornfix3.com")
        _ = try await InstanceBlockedDomain.create(domain: "pornfix4.com")
        
        // Act.
        let domains = try SharedApplication.application().getResponse(
            as: .user(userName: "wikiborin", password: "p@ssword"),
            to: "/instance-blocked-domains",
            method: .GET,
            decodeTo: PaginableResultDto<InstanceBlockedDomainDto>.self
        )

        // Assert.
        XCTAssertNotNil(domains, "Instance blocked domains should be returned.")
        XCTAssertTrue(domains.data.count > 0, "Some domains should be returned.")
    }
    
    func testForbiddenShouldbeReturnedForRegularUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "trelborin")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "trelborin", password: "p@ssword"),
            to: "/instance-blocked-domains",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testListOfInstanceBlockedDomainsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/instance-blocked-domains", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
