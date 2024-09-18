//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing

extension ActivityPubSharedControllerTests {
    
    @Suite("POST /inbox [Create]", .serialized, .tags(.shared))
    struct ActivityPubSharedCreateTests {
    }
}
