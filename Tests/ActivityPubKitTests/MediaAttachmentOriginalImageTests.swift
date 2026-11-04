//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import ActivityPubKit
import Foundation
import Testing

struct MediaAttachmentOriginalImageTests {
    @Test(arguments: [true, false])
    func originalImageFlagIsDecoded(value: Bool) throws {
        // Arrange.
        let data = attachmentJSON(field: ",\"originalImagePreserved\":\(value)")

        // Act.
        let attachment = try JSONDecoder().decode(MediaAttachmentDto.self, from: data)

        // Assert.
        #expect(attachment.originalImagePreserved == value)
    }

    @Test(arguments: [true, false])
    func originalImageFlagIsEncoded(value: Bool) throws {
        // Arrange.
        let data = attachmentJSON(field: ",\"originalImagePreserved\":\(value)")
        let attachment = try JSONDecoder().decode(MediaAttachmentDto.self, from: data)

        // Act.
        let encoded = try JSONEncoder().encode(attachment)

        // Assert.
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["originalImagePreserved"] as? Bool == value)
        #expect(object["useOriginalImage"] == nil)
    }

    @Test(arguments: ["", ",\"originalImagePreserved\":null"])
    func missingOrNullFlagDefaultsToFalse(field: String) throws {
        // Arrange.
        let data = attachmentJSON(field: field)

        // Act.
        let attachment = try JSONDecoder().decode(MediaAttachmentDto.self, from: data)

        // Assert.
        #expect(attachment.originalImagePreserved == false)
    }

    @Test
    func noteContextDefinesOriginalImageTerm() throws {
        // Arrange.
        let context = ContextDto.createNoteContext()

        // Act.
        let data = try JSONEncoder().encode(context)

        // Assert.
        let contexts = try #require(JSONSerialization.jsonObject(with: data) as? [Any])
        let extensionContext = try #require(contexts.compactMap { $0 as? [String: Any] }.first)
        #expect(extensionContext["photos"] as? String == "https://joinvernissage.org/ns#")
        #expect(extensionContext["originalImagePreserved"] as? String == "photos:originalImagePreserved")
    }

    private func attachmentJSON(field: String) -> Data {
        Data("{\"url\":\"https://example.org/photo.jpg\"\(field)}".utf8)
    }
}
