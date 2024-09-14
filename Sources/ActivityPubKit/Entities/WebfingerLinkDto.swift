//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct WebfingerLinkDto {
    public let rel: String
    public let type: String?
    public let href: String?
    public let template: String?
    
    public init(rel: String, type: String?, href: String?, template: String? = nil) {
        self.rel = rel
        self.type = type
        self.href = href
        self.template = template
    }
}

extension WebfingerLinkDto: Codable { }
extension WebfingerLinkDto: Sendable { }
