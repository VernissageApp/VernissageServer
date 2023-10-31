//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension ActivityPubClient {
    func note(url: URL) async throws -> NoteDto {
        let request = try Self.request(
            for: url,
            target: ActivityPub.Notes.get
        )
        
        return try await downloadJson(NoteDto.self, request: request)
    }
}
