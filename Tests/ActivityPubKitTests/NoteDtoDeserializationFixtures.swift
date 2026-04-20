//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum NoteDtoDeserializationFixtures {
    struct ExpectedExifData {
        let type: String
        let name: String
        let value: String
    }
    
    struct ExpectedNote {
        let id: String
        let type: String
        let content: String
        let attachmentType: String
        let attachmentUrl: String
        let attachmentMediaType: String
        let exifData: [ExpectedExifData]
    }
    
    static let expectedNote = ExpectedNote(
        id: "https://example.org/notes/1",
        type: "Note",
        content: "Sunrise photo.",
        attachmentType: "Image",
        attachmentUrl: "https://example.org/photos/123.jpg",
        attachmentMediaType: "image/jpeg",
        exifData: [
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
    )
    
    static let noteWithExifDataJson =
"""
{
    "@context": [
        "https://www.w3.org/ns/activitystreams",
        {
            "schema": "https://schema.org/"
        }
    ],
    "id": "https://example.org/notes/1",
    "type": "Note",
    "attributedTo": "https://example.org/users/alice",
    "content": "Sunrise photo.",
    "attachment": [{
        "type": "Image",
        "url": "https://example.org/photos/123.jpg",
        "mediaType": "image/jpeg",
        "exifData": [
            {
                "@type": "PropertyValue",
                "name": "DateTime",
                "value": "2025:03:30 06:30:00"
            },
            {
                "@type": "PropertyValue",
                "name": "ExposureTime",
                "value": "1/250"
            },
            {
                "@type": "PropertyValue",
                "name": "FNumber",
                "value": "f/5.6"
            },
            {
                "@type": "PropertyValue",
                "name": "FocalLength",
                "value": "70 mm"
            },
            {
                "@type": "PropertyValue",
                "name": "LensModel",
                "value": "Canon EF 70-200mm"
            },
            {
                "@type": "PropertyValue",
                "name": "Make",
                "value": "Canon"
            },
            {
                "@type": "PropertyValue",
                "name": "Model",
                "value": "EOS R5"
            },
            {
                "@type": "PropertyValue",
                "name": "PhotographicSensitivity",
                "value": "400"
            },
            {
                "@type": "PropertyValue",
                "name": "Software",
                "value": "Darktable"
            },
            {
                "@type": "PropertyValue",
                "name": "Chemistry",
                "value": "C-41"
            }
        ]
    }]
}
"""
}
