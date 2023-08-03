//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Controller for support shared functionality of ActivityPub.
final class ActivityPubSharedController: RouteCollection {
    
    public static let uri: PathComponent = .constant("shared")
    
    func boot(routes: RoutesBuilder) throws {
        let activityPubSharedGroup = routes.grouped(ActivityPubSharedController.uri)
        
        activityPubSharedGroup
            .grouped(EventHandlerMiddleware(.activityPubSharedInbox))
            .post("inbox", use: inbox)
    }
    
    /// Shared instance inbox.
    func inbox(request: Request) async throws -> HTTPStatus {
        request.logger.info("\(request.headers.description)")
        if let bodyString = request.body.string {
            request.logger.info("\(bodyString)")
        }
        
        // Deserialize activity from body.
        guard let activityDto = try request.body.activity() else {
            request.logger.warning("Shared inbox activity has not be deserialized.")
            return HTTPStatus.ok
        }
        
        // Add shared activity into queue.
        request.logger.info("Activity (type: '\(activityDto.type)', id: '\(activityDto.id)').")
        let headers = request.headers.dictionary()
        let activityPubRequest = ActivityPubRequestDto(activity: activityDto,
                                                       headers: headers,
                                                       bodyHash: request.body.hash(),
                                                       httpMethod: .post,
                                                       httpPath: .sharedInbox)

        try await request
            .queues(.apSharedInbox)
            .dispatch(ActivityPubSharedInboxJob.self, activityPubRequest)
        
        return HTTPStatus.ok
    }
}
