//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct NodeInfoLinkDto {
    public let rel: String
    public let href: String
}

extension NodeInfoLinkDto: Content { }
