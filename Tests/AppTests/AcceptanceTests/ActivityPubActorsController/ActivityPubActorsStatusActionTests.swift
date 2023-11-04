//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubActorsStatusActionTests: CustomTestCase {
    
    func testActorStatusShouldBeReturnedForExistingActor() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "trondfoter")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "AP note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let noteDto = try SharedApplication.application().getResponse(
            to: "/actors/trondfoter/statuses/\(statuses.first!.requireID())",
            version: .none,
            decodeTo: NoteDto.self
        )
        
        // Assert.
        XCTAssertEqual(noteDto.id, "http://localhost:8000/actors/trondfoter/statuses/\(statuses.first?.stringId() ?? "")", "Property 'id' is not valid.")
        XCTAssertEqual(noteDto.attachment?.count, 1, "Property 'attachment' is not valid.")
        XCTAssertEqual(noteDto.attributedTo, "http://localhost:8000/actors/trondfoter", "Property 'attributedTo' is not valid.")
        XCTAssertEqual(noteDto.url, "http://localhost:8080/@trondfoter/\(statuses.first?.stringId() ?? "")", "Property 'url' is not valid.")
    }
}
