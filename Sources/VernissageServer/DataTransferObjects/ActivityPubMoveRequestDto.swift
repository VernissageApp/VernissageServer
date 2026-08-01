//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ActivityPubMoveRequestDto {
    let source: String
    let target: String
    let sharedInbox: URL
    let id: Int64
    let privateKey: String

    init(source: String, target: String, sharedInbox: URL, id: Int64, privateKey: String) {
        self.source = source
        self.target = target
        self.sharedInbox = sharedInbox
        self.id = id
        self.privateKey = privateKey
    }
}

extension ActivityPubMoveRequestDto: Content { }
