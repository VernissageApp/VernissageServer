//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Testing
import Foundation

@Suite("NoteDto serialization")
struct NoteDtoSerializationTests {
    let encoder = JSONEncoder()
    
    init() {
        encoder.outputFormatting = [.sortedKeys]
    }
    
    @Test
    func `Note with exifData should serialize using @type field`() throws {
        // Arrange.
        let noteDto = NoteDtoSerializationFixtures.createNoteWithExifData()
        let expectedExifData = NoteDtoSerializationFixtures.expectedExifData
        
        // Act.
        let jsonData = try self.encoder.encode(noteDto)
        let rootObject = try #require(try JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        
        // Assert.
        let attachments = try #require(rootObject["attachment"] as? [[String: Any]])
        let exifData = try #require(attachments.first?["exifData"] as? [[String: Any]])
        #expect(exifData.count == expectedExifData.count)
        #expect(exifData.allSatisfy { $0["type"] == nil })
        
        for expectedExif in expectedExifData {
            #expect(exifData.first(where: { ($0["name"] as? String) == expectedExif.name })?["@type"] as? String == expectedExif.type)
            #expect(exifData.first(where: { ($0["name"] as? String) == expectedExif.name })?["value"] as? String == expectedExif.value)
        }
    }
}
