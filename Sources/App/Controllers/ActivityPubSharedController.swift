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
        
        // Activity without any data, strange...
        guard let data = request.body.wholeData else {
            return HTTPStatus.ok
        }
        
        // Activity with not recognized JSON structure.
        guard let activityDto = try? JSONDecoder().decode(ActivityDto.self, from: data) else {
            request.logger.warning("Activity has not be deserialized.")
            return HTTPStatus.ok
        }
        
        request.logger.info("Activity (type: '\(activityDto.type)', id: '\(activityDto.id)')")
        return HTTPStatus.ok
    }
}
