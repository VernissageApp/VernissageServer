//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ErrorBody: Content {
    var error: Bool;
    var code: String;
    var reason: String;
    var failures: [ValidationFailure]?
}