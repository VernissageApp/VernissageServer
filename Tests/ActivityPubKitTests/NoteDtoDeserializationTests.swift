//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Testing
import Foundation

@Suite("NoteDto deserialization")
struct NoteDtoDeserializationTests {
    let decoder = JSONDecoder()
    
    @Test
    func `Note with exifData should deserialize from FEP ee3a payload`() throws {
        // Arrange.
        let expected = NoteDtoDeserializationFixtures.expectedNote
        
        // Act.
        let noteDto = try self.decoder.decode(NoteDto.self, from: NoteDtoDeserializationFixtures.noteWithExifDataJson.data(using: .utf8)!)
        
        // Assert.
        #expect(noteDto.id == expected.id)
        #expect(noteDto.type == expected.type)
        #expect(noteDto.content == expected.content)
        
        let attachment = try #require(noteDto.attachment?.first)
        #expect(attachment.type == expected.attachmentType)
        #expect(attachment.url == expected.attachmentUrl)
        #expect(attachment.mediaType == expected.attachmentMediaType)
        
        let exifData = try #require(attachment.exifData)
        #expect(exifData.count == expected.exifData.count)
        
        for expectedExif in expected.exifData {
            #expect(exifData.first(where: { $0.name == expectedExif.name })?.type == expectedExif.type)
            #expect(exifData.first(where: { $0.name == expectedExif.name })?.value == expectedExif.value)
        }
    }
}
