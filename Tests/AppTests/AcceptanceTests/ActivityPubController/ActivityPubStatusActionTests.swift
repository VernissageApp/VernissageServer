//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubStatusActionTests: CustomTestCase {
    
    func testActorStatusShouldBeReturnedForExistingActor() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "trondfoter")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "AP note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let baseObjectDto = try SharedApplication.application().getResponse(
            to: "/actors/trondfoter/statuses/\(statuses.first!.requireID())",
            version: .none,
            decodeTo: BaseObjectDto.self
        )
        
        // Assert.
        XCTAssertEqual(baseObjectDto.id, "http://localhost:8000/actors/trondfoter/statuses/\(statuses.first?.id ?? 0)", "Property 'id' is not valid.")
        XCTAssertEqual(baseObjectDto.type, .note, "Property type is not valid.")
        XCTAssertEqual(baseObjectDto.attachment?.count, 1, "Property 'attachment' is not valid.")
        XCTAssertEqual(baseObjectDto.attributedTo, "http://localhost:8000/actors/trondfoter", "Property 'attributedTo' is not valid.")
    }
}
