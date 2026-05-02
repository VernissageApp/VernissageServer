//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Foundation

enum NoteDtoSerializationFixtures {
    struct ExpectedExifData {
        let type: String
        let name: String
        let value: String
    }
    
    static let expectedExifData: [ExpectedExifData] = [
        ExpectedExifData(type: "PropertyValue", name: "DateTime", value: "2025:03:30 06:30:00"),
        ExpectedExifData(type: "PropertyValue", name: "ExposureTime", value: "1/250"),
        ExpectedExifData(type: "PropertyValue", name: "FNumber", value: "f/5.6"),
        ExpectedExifData(type: "PropertyValue", name: "FocalLength", value: "70 mm"),
        ExpectedExifData(type: "PropertyValue", name: "LensModel", value: "Canon EF 70-200mm"),
        ExpectedExifData(type: "PropertyValue", name: "Make", value: "Canon"),
        ExpectedExifData(type: "PropertyValue", name: "Model", value: "EOS R5"),
        ExpectedExifData(type: "PropertyValue", name: "PhotographicSensitivity", value: "400"),
        ExpectedExifData(type: "PropertyValue", name: "Software", value: "Darktable"),
        ExpectedExifData(type: "PropertyValue", name: "Chemistry", value: "C-41")
    ]
    
    static func createNoteWithExifData() -> NoteDto {
        let exifData = expectedExifData.map { MediaExifDataDto(name: $0.name, value: $0.value) }
        
        let attachment = MediaAttachmentDto(
            mediaType: "image/jpeg",
            url: "https://example.org/photos/123.jpg",
            name: nil,
            blurhash: nil,
            width: nil,
            height: nil,
            hdrImageUrl: nil,
            exif: nil,
            exifData: exifData,
            location: nil
        )
        
        return NoteDto(
            id: "https://example.org/notes/1",
            summary: nil,
            inReplyTo: nil,
            published: nil,
            updated: nil,
            url: "https://example.org/notes/1",
            attributedTo: "https://example.org/users/alice",
            to: nil,
            cc: nil,
            sensitive: nil,
            atomUri: nil,
            inReplyToAtomUri: nil,
            conversation: nil,
            content: "Sunrise photo.",
            attachment: [attachment],
            tag: nil
        )
    }
}
