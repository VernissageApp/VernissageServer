//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class StatusesRebloggedActionTests: CustomTestCase {
    func testListOfRebloggedUsersShouldBeReturnedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "carinjorgi")
        let user2 = try await User.create(userName: "adamjorgi")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        _ = try await Status.reblog(user: user2, status: statuses.first!)
        
        // Act.
        let reblogged = try SharedApplication.application().getResponse(
            as: .user(userName: "carinjorgi", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/reblogged",
            method: .GET,
            decodeTo: LinkableResultDto<UserDto>.self
        )
        
        // Assert.
        XCTAssertEqual(reblogged.data.count, 1, "All followers should be returned.")
    }
}
