//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct WebfingerDto {
    public let subject: String
    public let aliases: [String]
    public let links: [WebfingerLinkDto]
}

extension WebfingerDto: Content { }
