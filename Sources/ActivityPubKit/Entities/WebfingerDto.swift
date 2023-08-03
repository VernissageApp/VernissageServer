//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct WebfingerDto {
    public let subject: String
    public let aliases: [String]
    public let links: [WebfingerLinkDto]
    
    public init(subject: String, aliases: [String], links: [WebfingerLinkDto]) {
        self.subject = subject
        self.aliases = aliases
        self.links = links
    }
}

extension WebfingerDto: Codable { }
