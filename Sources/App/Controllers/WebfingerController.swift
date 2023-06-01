//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

final class WebfingerController: RouteCollection {
    
    public static let uri: PathComponent = .constant(".well-known")
    
    func boot(routes: RoutesBuilder) throws {
        let webfingerGroup = routes.grouped(WebfingerController.uri)
        
        webfingerGroup
            .grouped(EventHandlerMiddleware(.webfinger))
            .get("webfinger", use: read)
    }
    
    func read(request: Request) async throws -> WebfingerDto {
        let resource: String? = request.query["resource"]
        
        guard let resource else {
            throw Abort(.badRequest)
        }
        
        let parts = resource.components(separatedBy: ":")
        let account = parts.last ?? resource

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
}
