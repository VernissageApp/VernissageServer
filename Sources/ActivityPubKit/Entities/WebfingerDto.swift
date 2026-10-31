//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public struct WebfingerDto {
    public let subject: String
    public let aliases: [String]?
    public let links: [WebfingerLinkDto]

    /// The actor URL advertised by an ActivityStreams self link.
    public var activityPubProfile: String? {
        let selfLinks = links.filter { $0.rel == "self" && $0.href?.isEmpty == false }
        if let link = selfLinks.first(where: {
            $0.type?.split(separator: ";").first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "application/activity+json"
        }) {
            return link.href
        }

        let jsonLdLink = selfLinks.first(where: { link in
            let components = link.type?.components(separatedBy: ";") ?? []
            guard components.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "application/ld+json" else {
                return false
            }
            return components.dropFirst().contains { parameter in
                let parts = parameter.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                return parts.count == 2 && parts[0].lowercased() == "profile"
                    && parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"")).split(separator: " ")
                        .contains("https://www.w3.org/ns/activitystreams")
            }
        })

        return jsonLdLink?.href
    }
    
    public init(subject: String, aliases: [String]?, links: [WebfingerLinkDto]) {
        self.subject = subject
        self.aliases = aliases
        self.links = links
    }
}

extension WebfingerDto: Codable { }
extension WebfingerDto: Sendable { }
