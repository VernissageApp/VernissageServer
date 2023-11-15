//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class StatusesListActionTests: CustomTestCase {

    func testListOfStatusesShouldBeReturnedForUnauthorized() async throws {

        // Arrange.
        let user = try await User.create(userName: "robincyan")

        let attachment1 = try await Attachment.create(user: user)
        defer {
            Status.clearFiles(attachments: [attachment1])
        }
        
        let attachment2 = try await Attachment.create(user: user)
        defer {
            Status.clearFiles(attachments: [attachment2])
        }
        
        let attachment3 = try await Attachment.create(user: user)
        defer {
            Status.clearFiles(attachments: [attachment3])
        }
        
        let lastStatus = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
        _ = try await Status.create(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!])
        _ = try await Status.create(user: user, note: "Note 3", attachmentIds: [attachment3.stringId()!])

        // Act.
        let statuses = try SharedApplication.application().getResponse(
            to: "/statuses?minId=\(lastStatus.stringId() ?? "")&limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )

        // Assert.
        XCTAssert(statuses.data.count == 2, "Statuses list should be returned.")
    }
    
    func testOtherUserPrivateStatusesShouldNotBeReturned() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "evelyncyan")
        let attachment1 = try await Attachment.create(user: user1)
        defer {
            Status.clearFiles(attachments: [attachment1])
        }
        
        let user2 = try await User.create(userName: "fredcyan")
        let attachment2 = try await Attachment.create(user: user2)
        defer {
            Status.clearFiles(attachments: [attachment2])
        }
                
        _ = try await Status.create(user: user1, note: "PRIVATE 1", attachmentIds: [attachment1.stringId()!], visibility: .followers)
        _ = try await Status.create(user: user2, note: "PRIVATE 2", attachmentIds: [attachment2.stringId()!], visibility: .followers)

        // Act.
        let statuses = try SharedApplication.application().getResponse(
            as: .user(userName: user1.userName, password: "p@ssword"),
            to: "/statuses?limit=40",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )

        // Assert.
        XCTAssertNotNil(statuses.data.filter({ $0.note == "PRIVATE 1" }).first, "Statuses list should contain private statuses signed in user.")
        XCTAssertNil(statuses.data.filter({ $0.note == "PRIVATE 2" }).first, "Statuses list should not contain private statuses other user.")
    }
}
