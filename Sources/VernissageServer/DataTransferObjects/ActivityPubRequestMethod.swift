//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

public enum ActivityPubRequestMethod: String, Sendable {
    case post = "post"
    case get = "get"
    case delete = "delete"
    case put = "put"
    case patch = "patch"
}

extension ActivityPubRequestMethod: Content { }
