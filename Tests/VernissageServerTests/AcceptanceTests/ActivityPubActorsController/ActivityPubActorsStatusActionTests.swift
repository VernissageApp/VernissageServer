//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing

extension ActivityPubActorControllerTests {
    
    @Suite("GET /:username/statuses/:id", .serialized, .tags(.actors))
    struct ActivityPubActorsStatusActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Actor status should be returned for existing actor")
        func actorStatusShouldBeReturnedForExistingActor() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "trondfoter")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "AP note", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let noteDto = try application.getResponse(
                to: "/actors/trondfoter/statuses/\(statuses.first!.requireID())",
                version: .none,
                decodeTo: NoteDto.self
            )
            
            // Assert.
            #expect(noteDto.id == "http://localhost:8080/actors/trondfoter/statuses/\(statuses.first?.stringId() ?? "")", "Property 'id' is not valid.")
            #expect(noteDto.attachment?.count == 1, "Property 'attachment' is not valid.")
            #expect(noteDto.attributedTo == "http://localhost:8080/actors/trondfoter", "Property 'attributedTo' is not valid.")
            #expect(noteDto.url == "http://localhost:8080/@trondfoter/\(statuses.first?.stringId() ?? "")", "Property 'url' is not valid.")
        }
    }
}
