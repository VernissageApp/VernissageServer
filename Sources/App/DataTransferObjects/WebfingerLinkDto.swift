import Vapor

struct WebfingerLinkDto {
    public let rel: String
    public let type: String
    public let href: String
}

extension WebfingerLinkDto: Content { }
