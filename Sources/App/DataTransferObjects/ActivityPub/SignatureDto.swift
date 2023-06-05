//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct SignatureDto: Content {
    public let type: String
    public let creator: String
    public let created: String
    public let signatureValue: String
}
