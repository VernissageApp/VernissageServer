//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Foundation

extension NoteDto {
    static func imageAttachmentNote(originalImagePreserved: Bool, fileName: String, includeHDR: Bool = false) throws -> NoteDto {
        let hdrField = includeHDR ? ",\"hdrImageUrl\":\"https://example.org/photo-hdr.jpg\"" : ""
        let json = """
        {
            "id":"https://example.org/status/1","type":"Note","attributedTo":"https://example.org/users/test",
            "attachment":[{"type":"Image","mediaType":"\(fileName.mimeType ?? "image/jpeg")",
            "url":"https://example.org/photo.jpg","originalImagePreserved":\(originalImagePreserved)\(hdrField)}]
        }
        """
        return try JSONDecoder().decode(NoteDto.self, from: Data(json.utf8))
    }
}
