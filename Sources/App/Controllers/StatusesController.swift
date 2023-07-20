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
            .grouped(UserAuthenticator())
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesCreate))
            .post(use: create)
        
        statusesGroup
            .grouped(EventHandlerMiddleware(.statusesList))
            .get(use: list)
        
        statusesGroup
            .grouped(EventHandlerMiddleware(.statusesRead))
            .get(":id", use: read)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesDelete))
            .delete(":id", use: delete)
    }
    
    /// Create new status.
    func create(request: Request) async throws -> Response {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let statusRequestDto = try request.content.decode(StatusRequestDto.self)
        try StatusRequestDto.validate(content: request)
        
        // Attachments can be ommited only for statused added as a comment to other status.
        if statusRequestDto.attachmentIds.count == 0 {
            guard let replyToStatusId = statusRequestDto.replyToStatusId?.toId() else {
                throw StatusError.attachmentsAreRequired
            }
            
            guard let _ = try await Status.find(replyToStatusId, on: request.db) else {
                throw EntityNotFoundError.statusNotFound
            }
        }
        
        // Verify attachments ids.
        var attachments: [Attachment] = []
        for attachmentId in statusRequestDto.attachmentIds {
            guard let attachmentId = attachmentId.toId() else {
                throw StatusError.incorrectAttachmentId
            }
            
            let attachment = try await Attachment.query(on: request.db)
                .filter(\.$id == attachmentId)
                .filter(\.$user.$id == authorizationPayloadId)
                .filter(\.$status.$id == nil)
                .with(\.$originalFile)
                .with(\.$smallFile)
                .with(\.$exif)
                .with(\.$location) { location in
                    location.with(\.$country)
                }
                .first()
            
            guard let attachment else {
                throw EntityNotFoundError.attachmentNotFound
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
        let response = try await self.createNewStatusResponse(on: request, status: status, attachments: attachmentsFromDatabase)
        return response
    }
    
    /// Exposing list of statuses.
    func list(request: Request) async throws -> [StatusDto] {
        let authorizationPayloadId = request.userId
        let size: Int = min(request.query["size"] ?? 10, 100)
        let page: Int = request.query["page"] ?? 0

        if let authorizationPayloadId {
            // For signed in users we can return public/unlisted statuses and all his own statuses.
            let statuses = try await Status.query(on: request.db)
                .group(.or) { group in
                    group
                        .filter(\.$visibility ~~ [.public, .unlisted])
                        .filter(\.$user.$id == authorizationPayloadId)
                }
                .with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .offset(page * size)
                .limit(size)
                .all()
            
            return statuses.map({ self.convertToDtos(on: request, status: $0, attachments: $0.attachments) })
        } else {
            // For anonymous users we can return only public/unlisted statuses.
            let statuses = try await Status.query(on: request.db)
                .filter(\.$visibility ~~ [.public, .unlisted])
                .with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .offset(page * size)
                .limit(size)
                .all()

            return statuses.map({ self.convertToDtos(on: request, status: $0, attachments: $0.attachments) })
        }
    }
    
    /// Get specific status.
    func read(request: Request) async throws -> StatusDto {
        let authorizationPayloadId = request.userId

        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        if let authorizationPayloadId {
            let status = try await Status.query(on: request.db)
                .filter(\.$id == statusId)
                .group(.or) { group in
                    group
                        .filter(\.$visibility ~~ [.public, .unlisted])
                        .filter(\.$user.$id == authorizationPayloadId)
                }
                .with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .first()

            guard let status else {
                throw EntityNotFoundError.statusNotFound
            }
            
            return self.convertToDtos(on: request, status: status, attachments: status.attachments)
        } else {
            let status = try await Status.query(on: request.db)
                .filter(\.$id == statusId)
                .filter(\.$visibility ~~ [.public, .unlisted])
                .with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .first()

            guard let status else {
                throw EntityNotFoundError.statusNotFound
            }
            
            return self.convertToDtos(on: request, status: status, attachments: status.attachments)
        }
    }
    
    /// Delete specific status.
    func delete(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }

        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let status = try await Status.query(on: request.db)
            .filter(\.$id == statusId)
            .with(\.$attachments) { attachment in
                attachment.with(\.$exif)
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
            }
            .first()
        
        guard let status else {
            throw EntityNotFoundError.statusNotFound
        }
        
        guard status.$user.id == authorizationPayloadId else {
            throw EntityForbiddenError.statusForbidden
        }

        try await request.db.transaction { database in
            for attachment in status.attachments {
                try await attachment.exif?.delete(on: database)
                try await attachment.delete(on: database)
                try await attachment.originalFile.delete(on: database)
                try await attachment.smallFile.delete(on: database)
            }
            
            try await status.delete(on: database)
        }

        return HTTPStatus.ok
    }
    
    private func createNewStatusResponse(on request: Request, status: Status, attachments: [Attachment]) async throws -> Response {
        let createdStatusDto = self.convertToDtos(on: request, status: status, attachments: attachments)
        let response = try await createdStatusDto.encodeResponse(for: request)

        response.headers.replaceOrAdd(name: .location, value: "/\(StatusesController.uri)/\(status.stringId() ?? "")")
        response.status = .created

        return response
    }
    
    private func convertToDtos(on request: Request, status: Status, attachments: [Attachment]) -> StatusDto {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request)

        let attachmentDtos = attachments.map({ AttachmentDto(from: $0, baseStoragePath: baseStoragePath) })
        return StatusDto(from: status, attachments: attachmentDtos)
    }
}
