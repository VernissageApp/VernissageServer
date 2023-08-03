//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct NodeInfoLinkDto {
    public let rel: String
    public let href: String
    
    public init(rel: String, href: String) {
        self.rel = rel
        self.href = href
    }
}

extension NodeInfoLinkDto: Codable { }
