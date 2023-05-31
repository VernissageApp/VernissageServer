import Vapor

struct WebfingerDto {
    public let subject: String
    public let aliases: [String]
    public let links: [WebfingerLinkDto]
}

extension WebfingerDto: Content { }
