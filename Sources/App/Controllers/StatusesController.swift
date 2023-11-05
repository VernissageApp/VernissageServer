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

        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesReblog))
            .post(":id", "reblog", use: reblog)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesUnreblog))
            .post(":id", "unreblog", use: unreblog)
    }
    
    /// Create new status.
    func create(request: Request) async throws -> Response {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let user = try await User.query(on: request.db).filter(\.$id == authorizationPayloadId).first() else {
            throw EntityNotFoundError.userNotFound
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
        
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        let attachmentsFromDatabase = attachments
        let status = Status(isLocal: true,
                            userId: authorizationPayloadId,
                            note: statusRequestDto.note,
                            baseAddress: baseAddress,
                            userName: user.userName,
                            application: request.applicationName,
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
            
            let hashtags = status.note?.getHashtags() ?? []
            for hashtag in hashtags {
                let statusHashtag = try StatusHashtag(statusId: status.requireID(), hashtag: hashtag)
                try await statusHashtag.save(on: database)
            }
            
            let userNames = status.note?.getUserNames() ?? []
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
        
        let statusFromDatabase = try await request.application.services.statusesService.get(on: request.db, id: status.requireID())
        guard let statusFromDatabase else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // Prepare and return status.
        let response = try await self.createNewStatusResponse(on: request, status: statusFromDatabase, attachments: attachmentsFromDatabase)
        return response
    }
    
    /// Exposing list of statuses.
    func list(request: Request) async throws -> [StatusDto] {
        let statusServices = request.application.services.statusesService
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
            
            return await statuses.asyncMap({
                await statusServices.convertToDtos(on: request, status: $0, attachments: $0.attachments)
            })
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

            return await statuses.asyncMap({
                await statusServices.convertToDtos(on: request, status: $0, attachments: $0.attachments)
            })
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
            
            let statusServices = request.application.services.statusesService
            let canView = try await statusServices.can(view: status, authorizationPayloadId: authorizationPayloadId, on: request)
            guard canView else {
                throw EntityNotFoundError.statusNotFound
            }
            
            return await statusServices.convertToDtos(on: request, status: status, attachments: status.attachments)
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
            
            let statusServices = request.application.services.statusesService
            return await statusServices.convertToDtos(on: request, status: status, attachments: status.attachments)
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
            .with(\.$user)
            .first()
        
        guard status?.$user.id == authorizationPayloadId else {
            throw EntityForbiddenError.statusForbidden
        }
        
        let statusServices = request.application.services.statusesService
        try await statusServices.delete(id: statusId, on: request.db)
        
        try await request
            .queues(.statusDeleter)
            .dispatch(StatusDeleterJob.self, statusId)

        return HTTPStatus.ok
    }
    
    /// Reblog (boost) specific status.
    func reblog(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let user = try await User.query(on: request.db).filter(\.$id == authorizationPayloadId).first() else {
            throw EntityNotFoundError.userNotFound
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        // We have to reblog orginal status, even when we get here already reblogged status.
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeReblog = try await statusesService.getOrginalStatus(id: statusId, on: request.db)
        guard let statusFromDatabaseBeforeReblog else {
            throw EntityNotFoundError.statusNotFound
        }

        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeReblog, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // Even if user have access to mentioned status, he/she shouldn't reblog it.
        guard statusFromDatabaseBeforeReblog.visibility != .mentioned else {
            throw StatusError.cannotReblogMentionedStatus
        }

        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        let reblogRequestDto = try request.content.decode(ReblogRequestDto?.self)

        let status = Status(isLocal: true,
                            userId: authorizationPayloadId,
                            note: nil,
                            baseAddress: baseAddress,
                            userName: user.userName,
                            application: request.applicationName,
                            visibility: (reblogRequestDto?.visibility ?? .public).translate(),
                            reblogId: statusId)
        
        try await status.create(on: request.db)
        try await statusesService.updateReblogsCount(for: statusId, on: request.db)
        
        try await request
            .queues(.statusReblogger)
            .dispatch(StatusRebloggerJob.self, status.requireID())
        
        // Prepare and return status.
        let statusFromDatabaseAfterReblog = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterReblog else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDtos(on: request, status: statusFromDatabaseAfterReblog, attachments: statusFromDatabaseAfterReblog.attachments)
    }
    
    /// Unreblog (revert boost) specific status.
    func unreblog(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
                
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        // We have to unreblog reblog status, even when we get here orginal status.
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeUnreblog = try await statusesService.getReblogStatus(id: statusId, userId: authorizationPayloadId, on: request.db)
        guard let statusFromDatabaseBeforeUnreblog else {
            throw EntityNotFoundError.statusNotFound
        }
        
        guard let mainStatusId = statusFromDatabaseBeforeUnreblog.$reblog.id else {
            throw EntityNotFoundError.userNotFound
        }
        
        // Delete reblog status from database.
        try await statusesService.delete(id: statusFromDatabaseBeforeUnreblog.requireID(), on: request.db)
        try await statusesService.updateReblogsCount(for: mainStatusId, on: request.db)
        
        let activityPubUnreblogDto = try ActivityPubUnreblogDto(reblogid: statusFromDatabaseBeforeUnreblog.requireID(),
                                                                activityPubReblogId: statusFromDatabaseBeforeUnreblog.activityPubId,
                                                                mainId: mainStatusId)
        
        try await request
            .queues(.statusUnreblogger)
            .dispatch(StatusUnrebloggerJob.self, activityPubUnreblogDto)
        
        // Prepare and return status.
        let statusFromDatabaseAfterUnreblog = try await statusesService.get(on: request.db, id: mainStatusId)
        guard let statusFromDatabaseAfterUnreblog else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDtos(on: request, status: statusFromDatabaseAfterUnreblog, attachments: statusFromDatabaseAfterUnreblog.attachments)
    }
    
    private func createNewStatusResponse(on request: Request, status: Status, attachments: [Attachment]) async throws -> Response {
        let statusServices = request.application.services.statusesService
        let createdStatusDto = await statusServices.convertToDtos(on: request, status: status, attachments: attachments)

        let response = try await createdStatusDto.encodeResponse(for: request)
        response.headers.replaceOrAdd(name: .location, value: "/\(StatusesController.uri)/\(status.stringId() ?? "")")
        response.status = .created

        return response
    }
}
