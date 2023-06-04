//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

final class ActivityPubSharedController: RouteCollection {
    
    public static let uri: PathComponent = .constant("shared")
    
    func boot(routes: RoutesBuilder) throws {
        let activityPubSharedGroup = routes.grouped(ActivityPubSharedController.uri)
        
        activityPubSharedGroup
            .grouped(EventHandlerMiddleware(.activityPubSharedInbox))
            .post("inbox", use: inbox)
    }
    
    func inbox(request: Request) async throws -> HTTPStatus {
        if let bodyString = request.body.string {
            request.logger.info("\(bodyString)")
        }

        return HTTPStatus.ok
    }
}
