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
        let status = Status(isLocal: true,
                            userId: authorizationPayloadId,
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
            
            let hashtags = status.note.getHashtags()
            for hashtag in hashtags {
                let statusHashtag = try StatusHashtag(statusId: status.requireID(), hashtag: hashtag)
                try await statusHashtag.save(on: database)
            }
            
            let userNames = status.note.getUserNames()
            for userName in userNames {
                let statusMention = try StatusMention(statusId: status.requireID(), userName: userName)
                try await statusMention.save(on: database)
            }
            
            try await request.application.services.statusesService.updateStatusCount(on: database, for: authorizationPayloadId)
            
            if let statusId = status.id {
                try await request
                    .queues(.statusSender)
                    .dispatch(StatusSenderJob.self, statusId)
            }
        }
        
        let statusFromDatabase = try await Status.query(on: request.db)
            .filter(\.$id == status.requireID())
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$exif)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$user)
            .first()
        
        guard let statusFromDatabase else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // Prepare and return status.
        let response = try await self.createNewStatusResponse(on: request, status: statusFromDatabase, attachments: attachmentsFromDatabase)
        return response
    }
    
    /// Exposing list of statuses.
    func list(request: Request) async throws -> [StatusDto] {
        let authorizationPayloadId = request.userId
        let size: Int = min(request.query["size"] ?? 10, 100)
        let page: Int = request.query["page"] ?? 0

        if let authorizationPayloadId {
            // For signed in users we can return public statuses and all his own statuses.
            let statuses = try await Status.query(on: request.db)
                .group(.or) { group in
                    group
                        .filter(\.$visibility ~~ [.public])
                        .filter(\.$user.$id == authorizationPayloadId)
                }
                .sort(\.$createdAt, .descending)
                .with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$user)
                .offset(page * size)
                .limit(size)
                .all()
            
            return statuses.map({ self.convertToDtos(on: request, status: $0, attachments: $0.attachments) })
        } else {
            // For anonymous users we can return only public statuses.
            let statuses = try await Status.query(on: request.db)
                .filter(\.$visibility ~~ [.public])
                .sort(\.$createdAt, .descending)
                .with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$user)
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
                .with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$user)
                .first()

            guard let status else {
                throw EntityNotFoundError.statusNotFound
            }
            
            let canView = try await self.canView(status: status, authorizationPayloadId: authorizationPayloadId, on: request)
            guard canView else {
                throw EntityNotFoundError.statusNotFound
            }
            
            return self.convertToDtos(on: request, status: status, attachments: status.attachments)
        } else {
            let status = try await Status.query(on: request.db)
                .filter(\.$id == statusId)
                .filter(\.$visibility ~~ [.public])
                .with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$user)
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
            
            try await request
                .queues(.statusDeleter)
                .dispatch(StatusDeleterJob.self, statusId)
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
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        let attachmentDtos = attachments.map({ AttachmentDto(from: $0, baseStoragePath: baseStoragePath) })
        return StatusDto(from: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath, attachments: attachmentDtos)
    }
    
    private func canView(status: Status, authorizationPayloadId: Int64, on request: Request) async throws -> Bool {
        // When user is owner of the status.
        if status.user.id == authorizationPayloadId {
            return true
        }

        // When status is public.
        if status.visibility == .public {
            return true
        }
        
        // Status visible for user (follower/mentioned).
        if try await UserStatus.query(on: request.db)
            .filter(\.$status.$id == status.requireID())
            .filter(\.$user.$id == authorizationPayloadId)
            .first() != nil {
            return true
        }
        
        return false
    }
}
