//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
@testable import ActivityPubKit
import Vapor
import Testing
import Queues

@Suite("StatusesService")
struct StatusesServiceTests {

    var application: Application!
    
    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }
    
    @Test("Correct category should be returned for list of tags.")
    func correctCategoryShouldBeReturnedForListOfTags() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let noteTagDtos = [NoteTagDto(type: "hashtag", name: "Street", href: ""), NoteTagDto(type: "hashtag", name: "Street", href: "")]
        
        // Act.
        let category = try await statusesService.getCategory(basedOn: noteTagDtos, on: application.db)
        
        // Arrange.
        #expect(category?.name == "Street", "Street category should be returned.")
    }
    
    @Test("Higher priority category should be returned for list of tags.")
    func higherPriorityCategoryShouldBeReturnedForListOfTags() async throws {
        // Arrange.
        let statusesService = StatusesService()
        try await self.application.setCategoryPriority(name: "Animals", priority: 1)
        try await self.application.setCategoryPriority(name: "Nature", priority: 2)
        let noteTagDtos = [NoteTagDto(type: "hashtag", name: "nature", href: ""), NoteTagDto(type: "hashtag", name: "pet", href: "")]
        
        // Act.
        let category = try await statusesService.getCategory(basedOn: noteTagDtos, on: application.db)
        
        // Arrange.
        #expect(category?.name == "Animals", "Animals category should be returned.")
    }
}
