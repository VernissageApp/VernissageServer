//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension StatusesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("statuses")
    
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
            .grouped(EventHandlerMiddleware(.statusesContext))
            .get(":id", "context", use: context)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesReblog))
            .post(":id", "reblog", use: reblog)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesUnreblog))
            .post(":id", "unreblog", use: unreblog)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesReblogged))
            .get(":id", "reblogged", use: reblogged)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesFavourite))
            .post(":id", "favourite", use: favourite)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesUnfavourite))
            .post(":id", "unfavourite", use: unfavourite)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesFavourited))
            .get(":id", "favourited", use: favourited)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesBookmark))
            .post(":id", "bookmark", use: bookmark)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesUnbookmark))
            .post(":id", "unbookmark", use: unbookmark)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesFeature))
            .post(":id", "feature", use: feature)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesUnfeature))
            .post(":id", "unfeature", use: unfeature)
    }
}

/// Operations on statuses.
final class StatusesController {
    
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
                .with(\.$license)
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
                            categoryId: statusRequestDto.categoryId?.toId(),
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
    func list(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let statusesService = request.application.services.statusesService
        let authorizationPayloadId = request.userId
        let linkableParams = request.linkableParams()

        if let authorizationPayloadId {
            // For signed in users we can return public statuses and all his own statuses.
            let linkableStatuses = try await statusesService.statuses(for: authorizationPayloadId, linkableParams: linkableParams, on: request)
            let statusDtos = await statusesService.convertToDtos(on: request, statuses: linkableStatuses.data)
            
            return LinkableResultDto(
                maxId: linkableStatuses.maxId,
                minId: linkableStatuses.minId,
                data: statusDtos
            )
        } else {
            // For anonymous users we can return only public statuses.
            let linkableStatuses = try await statusesService.statuses(linkableParams: linkableParams, on: request)
            let statusDtos = await statusesService.convertToDtos(on: request, statuses: linkableStatuses.data)
            
            return LinkableResultDto(
                maxId: linkableStatuses.maxId,
                minId: linkableStatuses.minId,
                data: statusDtos
            )
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
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$category)
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
            
            return await statusServices.convertToDto(on: request, status: status, attachments: status.attachments)
        } else {
            let status = try await Status.query(on: request.db)
                .filter(\.$id == statusId)
                .filter(\.$visibility ~~ [.public])
                .with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$category)
                .with(\.$user)
                .first()

            guard let status else {
                throw EntityNotFoundError.statusNotFound
            }
            
            let statusServices = request.application.services.statusesService
            return await statusServices.convertToDto(on: request, status: status, attachments: status.attachments)
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
        
        guard let status else {
            throw EntityNotFoundError.statusNotFound
        }
        
        guard status.$user.id == authorizationPayloadId || request.isModerator || request.isAdministrator else {
            throw EntityForbiddenError.statusForbidden
        }
        
        let statusServices = request.application.services.statusesService
        try await statusServices.delete(id: statusId, on: request.db)
                
        if status.isLocal {
            try await request
                .queues(.statusDeleter)
                .dispatch(StatusDeleterJob.self, StatusDeleteJobDto(userId: status.user.requireID(), activityPubStatusId: status.activityPubId))
        }

        return HTTPStatus.ok
    }
    
    /// Status context. View statuses above and below this status in the thread.
    func context(request: Request) async throws -> StatusContextDto {
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let ancestors = try await statusesService.ancestors(for: statusId, on: request.db)
        let descendants = try await statusesService.descendants(for: statusId, on: request.db)
        
        let ancestorsDtos = await statusesService.convertToDtos(on: request, statuses: ancestors)
        let descendantsDtos = await statusesService.convertToDtos(on: request, statuses: descendants)
        
        return StatusContextDto(ancestors: ancestorsDtos, descendants: descendantsDtos)
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

        // We cannot reblogs comments (there is no place wehere we can see them).
        guard statusFromDatabaseBeforeReblog.$replyToStatus.id == nil else {
            throw StatusError.cannotReblogComments
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
                            categoryId: nil,
                            visibility: (reblogRequestDto?.visibility ?? .public).translate(),
                            reblogId: statusId)
        
        // Save status and recalculate reblogs count.
        try await status.create(on: request.db)
        try await statusesService.updateReblogsCount(for: statusId, on: request.db)
        
        // Add new notification.
        let notificationsService = request.application.services.notificationsService
        try await notificationsService.create(type: .reblog,
                                              to: statusFromDatabaseBeforeReblog.user,
                                              by: authorizationPayloadId,
                                              statusId: statusId,
                                              on: request.db)
        
        try await request
            .queues(.statusReblogger)
            .dispatch(StatusRebloggerJob.self, status.requireID())
        
        // Prepare and return status.
        let statusFromDatabaseAfterReblog = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterReblog else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterReblog,
                                                   attachments: statusFromDatabaseAfterReblog.attachments)
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
        
        // Download main (reblogged) status.
        guard let mainStatusId = statusFromDatabaseBeforeUnreblog.$reblog.id,
              let mainStatus = try await statusesService.get(on: request.db, id: mainStatusId) else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // Delete reblog status from database.
        try await statusesService.delete(id: statusFromDatabaseBeforeUnreblog.requireID(), on: request.db)
        try await statusesService.updateReblogsCount(for: mainStatusId, on: request.db)
        
        // Delete notification about reblog.
        let notificationsService = request.application.services.notificationsService
        try await notificationsService.delete(type: .reblog,
                                              to: mainStatus.$user.id,
                                              by: authorizationPayloadId,
                                              statusId: mainStatusId,
                                              on: request.db)
        
        let activityPubUnreblogDto = try ActivityPubUnreblogDto(activityPubStatusId: statusFromDatabaseBeforeUnreblog.activityPubId,
                                                                activityPubProfile: statusFromDatabaseBeforeUnreblog.user.activityPubProfile,
                                                                published: statusFromDatabaseBeforeUnreblog.createdAt ?? Date(),
                                                                activityPubReblogProfile: mainStatus.user.activityPubProfile,
                                                                activityPubReblogStatusId: mainStatus.activityPubId,
                                                                statusId: statusFromDatabaseBeforeUnreblog.requireID(),
                                                                userId: authorizationPayloadId,
                                                                orginalStatusId: mainStatusId)
        
        try await request
            .queues(.statusUnreblogger)
            .dispatch(StatusUnrebloggerJob.self, activityPubUnreblogDto)
        
        // Prepare and return status.
        let statusFromDatabaseAfterUnreblog = try await statusesService.get(on: request.db, id: mainStatusId)
        guard let statusFromDatabaseAfterUnreblog else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterUnreblog,
                                                   attachments: statusFromDatabaseAfterUnreblog.attachments)
    }
    
    /// Users who reblogged status.
    func reblogged(request: Request) async throws -> LinkableResultDto<UserDto> {
        let linkableParams = request.linkableParams()
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let linkableUsers = try await statusesService.reblogged(on: request, statusId: statusId, linkableParams: linkableParams)
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let userProfiles = try await linkableUsers.data.parallelMap { user in
            let flexiFields = try await user.$flexiFields.get(on: request.db)
            return UserDto(from: user, flexiFields: flexiFields, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
        }
        
        return LinkableResultDto(
            maxId: linkableUsers.maxId,
            minId: linkableUsers.minId,
            data: userProfiles
        )
    }
    
    /// Favourite specific status.
    func favourite(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
                
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeFavourite = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeFavourite else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeFavourite, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if try await StatusFavourite.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() == nil {
            // Save information about new favourite.
            let statusFavourite = StatusFavourite(statusId: statusId, userId: authorizationPayloadId)
            try await statusFavourite.save(on: request.db)
            try await statusesService.updateFavouritesCount(for: statusId, on: request.db)
            
            // Add new notification.
            let notificationsService = request.application.services.notificationsService
            try await notificationsService.create(type: .favourite,
                                                  to: statusFromDatabaseBeforeFavourite.user,
                                                  by: authorizationPayloadId,
                                                  statusId: statusId,
                                                  on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterFavourite = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterFavourite else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterFavourite,
                                                   attachments: statusFromDatabaseAfterFavourite.attachments)
    }
    
    /// Unfavourite specific status.
    func unfavourite(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeUnfavourite = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeUnfavourite else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeUnfavourite, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if let statusFavourite = try await StatusFavourite.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() {
            // Delete information about favourite.
            try await statusFavourite.delete(on: request.db)
            try await statusesService.updateFavouritesCount(for: statusId, on: request.db)
            
            // Delete notification about favourite.
            let notificationsService = request.application.services.notificationsService
            try await notificationsService.delete(type: .favourite,
                                                  to: statusFromDatabaseBeforeUnfavourite.$user.id,
                                                  by: authorizationPayloadId,
                                                  statusId: statusId,
                                                  on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterUnfavourite = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterUnfavourite else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterUnfavourite,
                                                   attachments: statusFromDatabaseAfterUnfavourite.attachments)
    }
    
    /// Users who favourited status.
    func favourited(request: Request) async throws -> LinkableResultDto<UserDto> {
        let linkableParams = request.linkableParams()
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let linkableUsers = try await statusesService.favourited(on: request, statusId: statusId, linkableParams: linkableParams)
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let userProfiles = try await linkableUsers.data.parallelMap { user in
            let flexiFields = try await user.$flexiFields.get(on: request.db)
            return UserDto(from: user, flexiFields: flexiFields, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
        }
        
        return LinkableResultDto(
            maxId: linkableUsers.maxId,
            minId: linkableUsers.minId,
            data: userProfiles
        )
    }

    /// Bookmark specific status.
    func bookmark(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeBookmark = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeBookmark else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeBookmark, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if try await StatusBookmark.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() == nil {
            let statusBookmark = StatusBookmark(statusId: statusId, userId: authorizationPayloadId)
            try await statusBookmark.save(on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterBookmark = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterBookmark else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request, status: statusFromDatabaseAfterBookmark, attachments: statusFromDatabaseAfterBookmark.attachments)
    }
    
    /// Unbookmark specific status.
    func unbookmark(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeUnbookmark = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeUnbookmark else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeUnbookmark, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if let statusBookmark = try await StatusBookmark.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() {
            try await statusBookmark.delete(on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterUnbookmark = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterUnbookmark else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterUnbookmark,
                                                   attachments: statusFromDatabaseAfterUnbookmark.attachments)
    }
    
    /// Feature specific status.
    func feature(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeFeature = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeFeature else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeFeature, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if try await FeaturedStatus.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() == nil {
            let featuredStatus = FeaturedStatus(statusId: statusId, userId: authorizationPayloadId)
            try await featuredStatus.save(on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterFeature = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterFeature else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request, status: statusFromDatabaseAfterFeature, attachments: statusFromDatabaseAfterFeature.attachments)
    }
    
    /// Unfeature specific status.
    func unfeature(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeUnfeature = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeUnfeature else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeUnfeature, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if let featuredStatus = try await FeaturedStatus.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() {
            try await featuredStatus.delete(on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterUnfeature = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterUnfeature else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterUnfeature,
                                                   attachments: statusFromDatabaseAfterUnfeature.attachments)
    }
    
    private func createNewStatusResponse(on request: Request, status: Status, attachments: [Attachment]) async throws -> Response {
        let statusServices = request.application.services.statusesService
        let createdStatusDto = await statusServices.convertToDto(on: request, status: status, attachments: attachments)

        let response = try await createdStatusDto.encodeResponse(for: request)
        response.headers.replaceOrAdd(name: .location, value: "/\(StatusesController.uri)/\(status.stringId() ?? "")")
        response.status = .created

        return response
    }
}
