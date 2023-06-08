//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

/// Controller which epxpose Well-Known functionality (webfinger, nodeinfo, host-meta).
final class WellKnownController: RouteCollection {
    
    public static let uri: PathComponent = .constant(".well-known")
    
    func boot(routes: RoutesBuilder) throws {
        let wellKnownGroup = routes.grouped(WellKnownController.uri)
        
        wellKnownGroup
            .grouped(EventHandlerMiddleware(.webfinger))
            .get("webfinger", use: webfinger)

        wellKnownGroup
            .grouped(EventHandlerMiddleware(.nodeinfo))
            .get("nodeinfo", use: nodeinfo)

        wellKnownGroup
            .grouped(EventHandlerMiddleware(.hostMeta))
            .get("host-meta", use: hostMeta)
    }
    
    func webfinger(request: Request) async throws -> WebfingerDto {
        let resource: String? = request.query["resource"]
        
        guard let resource else {
            throw Abort(.badRequest)
        }
        
        let account = resource.deletingPrefix("acct:")

        let usersService = request.application.services.usersService
        let userFromDb = try await usersService.get(on: request, account: account)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        let baseAddress = appplicationSettings?.baseAddress ?? ""

        return WebfingerDto(subject: "acct:\(user.account)",
                            aliases: ["\(baseAddress)/\(user.userName)", "\(baseAddress)/actors/\(user.userName)"],
                            links: [
                                WebfingerLinkDto(rel: "self",
                                                 type: "application/activity+json",
                                                 href: "\(baseAddress)/actors/\(user.userName)"),
                                WebfingerLinkDto(rel: "http://webfinger.net/rel/profile-page",
                                                 type: "text/html",
                                                 href: "\(baseAddress)/\(user.userName)")
                         ])
    }
    
    func nodeinfo(request: Request) async throws -> NodeInfoLinkDto {
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        let baseAddress = appplicationSettings?.baseAddress ?? ""

        return NodeInfoLinkDto(rel: "http://nodeinfo.diaspora.software/ns/schema/2.0",
                               href: "\(baseAddress)/api/v1/nodeinfo/2.0")
    }
    
    func hostMeta(request: Request) async throws -> Response {
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        
        let hostMetaBody =
"""
<?xml version="1.0" encoding="UTF-8"?>
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
    <Link rel="lrdd" template="\(baseAddress)/.well-known/webfinger?resource={uri}"/>
</XRD>
"""

        var headers = HTTPHeaders()
        headers.contentType = .init(type: "application", subType: "xrd+xml", parameters: ["charset": "utf-8"])
        
        return Response(headers: headers, body: Response.Body(string: hostMetaBody))
    }
    
}
