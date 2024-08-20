//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class InstanceBlockedDomainsDeleteActionTests: CustomTestCase {
    func testInstanceBlockedDomainShouldBeDeletedByAuthorizedUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "laragibro")
        try await user.attach(role: Role.moderator)

        let orginalInstanceBlockedDomain = try await InstanceBlockedDomain.create(domain: "stupid01.com")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "laragibro", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be created (200).")
        let instanceBlockedDomain = try await InstanceBlockedDomain.get(domain: "stupid01.com")
        XCTAssertNil(instanceBlockedDomain, "Instance blocked domain should be deleted.")
    }
    
    func testForbiddenShouldBeReturneddForRegularUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "nogogibro")
        let orginalInstanceBlockedDomain = try await InstanceBlockedDomain.create(domain: "stupid02.com")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nogogibro", password: "p@ssword"),
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
    }
    
    func testUnauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "yorigibro")
        let orginalInstanceBlockedDomain = try await InstanceBlockedDomain.create(domain: "stupid03.com")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/instance-blocked-domains/" + (orginalInstanceBlockedDomain.stringId() ?? ""),
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
