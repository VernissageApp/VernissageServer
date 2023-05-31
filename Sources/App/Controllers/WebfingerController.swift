import Vapor

final class WebfingerController: RouteCollection {
    
    public static let uri: PathComponent = .constant(".well-known")
    
    func boot(routes: RoutesBuilder) throws {
        let webfingerGroup = routes.grouped(WebfingerController.uri)
        
        webfingerGroup
            .grouped(EventHandlerMiddleware(.registerUserName))
            .get("webfinger", use: webfinger)
    }
    
    func webfinger(request: Request) async throws -> WebfingerDto {
        // let resource = req.query["resource"]

        return WebfingerDto(subject: "acct:mczachurski@vernissage.photos",
                            aliases: ["https://vernissage.photos/mczachurski", "https://vernissage.photos/users/mczachurski"],
                            links: [
                                WebfingerLinkDto(rel: "http://webfinger.net/rel/profile-page",
                                                 type: "text/html",
                                                 href: "https://vernissage.photos/mczachurski"),
                                WebfingerLinkDto(rel: "http://schemas.google.com/g/2010#updates-from",
                                                 type: "application/atom+xml",
                                                 href: "https://vernissage.photos/users/mczachurski.atom"),
                                WebfingerLinkDto(rel: "self",
                                                 type: "application/activity+json",
                                                 href: "https://vernissage.photos/users/mczachurski")
                         ])
    }
}
