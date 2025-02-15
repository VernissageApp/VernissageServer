//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct NodeInfoLinksDto {
    public let links: [NodeInfoLinkDto]
    
    public init(links: [NodeInfoLinkDto]) {
        self.links = links
    }
}

extension NodeInfoLinksDto: Codable { }
extension NodeInfoLinksDto: Sendable { }
