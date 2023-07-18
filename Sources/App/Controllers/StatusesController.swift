//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

final class StatusesController: RouteCollection {
    
    public static let uri: PathComponent = .constant("statuses")
    
    func boot(routes: RoutesBuilder) throws {
        let statusesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(StatusesController.uri)
        
        statusesGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesCreate))
            .post(use: create)
        
        statusesGroup
            .grouped(EventHandlerMiddleware(.statusesList))
            .get(use: list)
    }
    
    /// Create new status.
    func create(request: Request) async throws -> Response {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.badRequest)
        }
        
        let statusRequestDto = try request.content.decode(StatusRequestDto.self)
        try StatusRequestDto.validate(content: request)
        
        if statusRequestDto.attachmentIds.count == 0 {
            throw Abort(.badRequest)
        }
        
        // Verify attachments ids.
        var attachments: [Attachment] = []
        for attachmentId in statusRequestDto.attachmentIds {
            guard let attachmentId = attachmentId.toId() else {
                throw Abort(.badRequest)
            }
            
            guard let attachment = try await Attachment.query(on: request.db)
                .filter(\.$id == attachmentId)
                .filter(\.$user.$id == authorizationPayloadId)
                .filter(\.$status.$id == nil)
                .first() else {
                throw Abort(.badRequest)
            }
            
            attachments.append(attachment)
        }
        
        let attachmentsFromDatabase = attachments
        let status = Status(userId: authorizationPayloadId,
                            note: statusRequestDto.note,
                            visibility: statusRequestDto.visibility.translate(),
                            sensitive: statusRequestDto.sensitive,
                            contentWarning: statusRequestDto.contentWarning,
                            commentsDisabled: statusRequestDto.commentsDisabled,
                            replyToStatusId: statusRequestDto.replyToStatusId?.toId())
        
        // Save status and attachments into database (in one transaction).
        try await request.db.transaction { database in
            try await status.create(on: database)
            
            for attachment in attachmentsFromDatabase {
                attachment.$status.id = status.id
                try await attachment.save(on: database)
            }
        }
        
        // Prepare and return status.
        let response = try await self.createNewStatusResponse(on: request, status: status)
        return response
    }
    
    /// Exposing list of statuses.
    func list(request: Request) async throws -> [StatusDto] {
        return []
    }
    
    private func createNewStatusResponse(on request: Request, status: Status) async throws -> Response {
        let createdStatusDto = StatusDto(from: status)

        let response = try await createdStatusDto.encodeResponse(for: request)
        response.headers.replaceOrAdd(name: .location, value: "/\(StatusesController.uri)/\(status.stringId() ?? "")")
        response.status = .created

        return response
    }
}
