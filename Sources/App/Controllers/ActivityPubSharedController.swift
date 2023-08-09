//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues

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
        let bodyHash = request.body.hash()
        request.logger.info("Activity (type: '\(activityDto.type)', id: '\(activityDto.id)', body hash: '\(bodyHash ?? "")').")
        let headers = request.headers.dictionary()
        let activityPubRequest = ActivityPubRequestDto(activity: activityDto,
                                                       headers: headers,
                                                       bodyHash: bodyHash,
                                                       httpMethod: .post,
                                                       httpPath: .sharedInbox)
        
        // When echo queue driver is used (e.g. during unit tests) we have to execute request immediatelly.
        if let _ = request.application.queues.driver as? EchoQueuesDriver {
            let queue = ActivityPubSharedInboxJob()
            let queueContext = QueueContext(queueName: .apSharedInbox,
                                            configuration: .init(),
                                            application: request.application,
                                            logger: request.logger,
                                            on: request.eventLoop)

            try await queue.dequeue(queueContext, activityPubRequest)
        } else {
            try await request
                .queues(.apSharedInbox)
                .dispatch(ActivityPubSharedInboxJob.self, activityPubRequest)
        }
        
        return HTTPStatus.ok
    }
}
