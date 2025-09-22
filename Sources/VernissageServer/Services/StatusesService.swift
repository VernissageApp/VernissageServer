//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import FluentSQL
import Queues
import ActivityPubKit
import SwiftGD

extension Application.Services {
    struct StatusesServiceKey: StorageKey {
        typealias Value = StatusesServiceType
    }

    var statusesService: StatusesServiceType {
        get {
            self.application.storage[StatusesServiceKey.self] ?? StatusesService()
        }
        nonmutating set {
            self.application.storage[StatusesServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol StatusesServiceType: Sendable {
    /// Retrieves a status by its ActivityPub Id.
    ///
    /// - Parameters:
    ///   - activityPubId: The ActivityPub identifier of the status.
    ///   - database: The database to query against.
    /// - Returns: The matching status or nil if not found.
    /// - Throws: An error if the database query fails.
    func get(activityPubId: String, on database: Database) async throws -> Status?
    
    /// Retrieves a status by its internal Id.
    ///
    /// - Parameters:
    ///   - id: The internal identifier of the status.
    ///   - database: The database to query against.
    /// - Returns: The matching status or nil if not found.
    /// - Throws: An error if the database query fails.
    func get(id: Int64, on database: Database) async throws -> Status?
    
    /// Retrieves multiple statuses by an array of internal Ids.
    ///
    /// - Parameters:
    ///   - ids: An array of internal status identifiers.
    ///   - database: The database to query against.
    /// - Returns: An array of matching statuses.
    /// - Throws: An error if the database query fails.
    func get(ids: [Int64], on database: Database) async throws -> [Status]
    
    /// Retrieves all statuses for a given user.
    ///
    /// - Parameters:
    ///   - userId: The user identifier.
    ///   - database: The database to query against.
    /// - Returns: An array of statuses for the user.
    /// - Throws: An error if the database query fails.
    func all(userId: Int64, on database: Database) async throws -> [Status]
    
    /// Counts the total number of statuses for a given user.
    ///
    /// - Parameters:
    ///   - userId: The user identifier.
    ///   - database: The database to query against.
    /// - Returns: The count of statuses.
    /// - Throws: An error if the database query fails.
    func count(for userId: Int64, on database: Database) async throws -> Int
    
    /// Counts statuses based on whether only comments should be counted.
    ///
    /// - Parameters:
    ///   - onlyComments: If true, count only comments; otherwise, count only non-comments.
    ///   - database: The database to query against.
    /// - Returns: The count of statuses or comments.
    /// - Throws: An error if the database query fails.
    func count(onlyComments: Bool, on database: Database) async throws -> Int
    
    /// Retrieves the history of a status by its Id.
    ///
    /// - Parameters:
    ///   - id: The internal identifier of the original status.
    ///   - database: The database to query against.
    /// - Returns: An array of status history entries.
    /// - Throws: An error if the database query fails.
    func get(history id: Int64, on database: Database) async throws -> [StatusHistory]
    
    /// Creates a NoteDto based on a given status and optionally a reply status.
    ///
    /// - Parameters:
    ///   - status: The base status to create the note from.
    ///   - replyToStatus: An optional status that this note is replying to.
    ///   - context: The execution context for database and services.
    /// - Returns: A NoteDto representing the status.
    /// - Throws: An error if the operation fails.
    func note(basedOn status: Status, replyToStatus: Status?, on context: ExecutionContext) async throws -> NoteDto
    
    /// Updates the status count and related counters for a user.
    ///
    /// - Parameters:
    ///   - userId: The user identifier.
    ///   - database: The database to update.
    /// - Throws: An error if the update fails.
    func updateStatusCount(for userId: Int64, on database: Database) async throws
    
    /// Sends a status to the appropriate timelines and recipients.
    ///
    /// - Parameters:
    ///   - statusId: The internal identifier of the status to send.
    ///   - context: The execution context for database and services.
    /// - Throws: An error if sending fails.
    func send(status statusId: Int64, on context: ExecutionContext) async throws
    
    /// Sends an update for an existing status.
    ///
    /// - Parameters:
    ///   - statusId: The internal identifier of the status to update.
    ///   - context: The execution context for database and services.
    /// - Throws: An error if sending fails.
    func send(update statusId: Int64, on context: ExecutionContext) async throws
    
    /// Sends a reblog action for a status.
    ///
    /// - Parameters:
    ///   - statusId: The internal identifier of the status to reblog.
    ///   - context: The execution context for database and services.
    /// - Throws: An error if sending fails.
    func send(reblog statusId: Int64, on context: ExecutionContext) async throws
    
    /// Sends an unreblog action based on the given ActivityPub unreblog data.
    ///
    /// - Parameters:
    ///   - activityPubUnreblog: The data representing the unreblog activity.
    ///   - context: The execution context for database and services.
    /// - Throws: An error if sending fails.
    func send(unreblog activityPubUnreblog: ActivityPubUnreblogDto, on context: ExecutionContext) async throws
    
    /// Sends a favourite action for a status favourite ID.
    ///
    /// - Parameters:
    ///   - statusFavouriteId: The internal identifier of the status favourite.
    ///   - context: The execution context for database and services.
    /// - Throws: An error if sending fails.
    func send(favourite statusFavouriteId: Int64, on context: ExecutionContext) async throws
    
    /// Sends an unfavourite action based on the given data.
    ///
    /// - Parameters:
    ///   - statusFavouriteDto: The data representing the unfavourite action.
    ///   - context: The execution context for database and services.
    /// - Throws: An error if sending fails.
    func send(unfavourite statusFavouriteDto: StatusUnfavouriteJobDto, on context: ExecutionContext) async throws
    
    /// Creates a new status based on a NoteDto.
    ///
    /// - Parameters:
    ///   - noteDto: The NoteDto containing status information.
    ///   - userId: The user identifier creating the status.
    ///   - context: The execution context for database and services.
    /// - Returns: The created Status.
    /// - Throws: An error if creation fails.
    func create(basedOn noteDto: NoteDto, userId: Int64, on context: ExecutionContext) async throws -> Status
    
    /// Creates a new status based on a StatusRequestDto.
    ///
    /// - Parameters:
    ///   - statusRequestDto: The request data for the status.
    ///   - user: The user creating the status.
    ///   - request: The current HTTP request.
    /// - Returns: The created Status.
    /// - Throws: An error if creation fails.
    func create(basedOn statusRequestDto: StatusRequestDto, user: User, on request: Request) async throws -> Status
    
    /// Updates an existing status based on a NoteDto, preserving history.
    ///
    /// - Parameters:
    ///   - status: The status to update.
    ///   - noteDto: The NoteDto containing updated data.
    ///   - context: The execution context for database and services.
    /// - Returns: The updated Status.
    /// - Throws: An error if the update fails.
    func update(status: Status, basedOn noteDto: NoteDto, on context: ExecutionContext) async throws -> Status
    
    /// Updates an existing status based on a StatusRequestDto, preserving history.
    ///
    /// - Parameters:
    ///   - status: The status to update.
    ///   - statusRequestDto: The request data containing updated information.
    ///   - request: The current HTTP request.
    /// - Returns: The updated Status.
    /// - Throws: An error if the update fails.
    func update(status: Status, basedOn statusRequestDto: StatusRequestDto, on request: Request) async throws -> Status
    
    /// Creates status entries on the local timeline for followers of a user.
    ///
    /// - Parameters:
    ///   - userId: The user whose followers will receive the status.
    ///   - status: The status to propagate.
    ///   - context: The execution context for database and services.
    /// - Throws: An error if the operation fails.
    func createOnLocalTimeline(followersOf userId: Int64, status: Status, on context: ExecutionContext) async throws
    
    /// Converts a status to a Data Transfer Object (DTO).
    ///
    /// - Parameters:
    ///   - status: The status to convert.
    ///   - attachments: Attachments associated with the status.
    ///   - attachUserInteractions: Whether to include user interaction flags.
    ///   - context: The execution context for database and services.
    /// - Returns: The converted StatusDto.
    func convertToDto(status: Status, attachments: [Attachment], attachUserInteractions: Bool, on context: ExecutionContext) async -> StatusDto
    
    /// Converts multiple statuses to DTOs.
    ///
    /// - Parameters:
    ///   - statuses: The statuses to convert.
    ///   - context: The execution context for database and services.
    /// - Returns: An array of StatusDto objects.
    func convertToDtos(statuses: [Status], on context: ExecutionContext) async -> [StatusDto]
    
    /// Converts multiple status histories to DTOs.
    ///
    /// - Parameters:
    ///   - statusHistories: The status histories to convert.
    ///   - context: The execution context for database and services.
    /// - Returns: An array of StatusDto objects.
    func convertToDtos(statusHistories: [StatusHistory], on context: ExecutionContext) async -> [StatusDto]

    /// Converts multiple status ActivityPub events to DTOs.
    ///
    /// - Parameters:
    ///   - statusActivityPubEvents: The status ActivityPub events to convert.
    ///   - context: The execution context for database and services.
    /// - Returns: An array of StatusDto objects.
    func convertToDtos(statusActivityPubEvents: [StatusActivityPubEvent], on context: ExecutionContext) async -> [StatusActivityPubEventDto]

    /// Converts multiple status ActivityPub event items to DTOs.
    ///
    /// - Parameters:
    ///   - statusActivityPubEventItems: The status ActivityPub event items to convert.
    ///   - context: The execution context for database and services.
    /// - Returns: An array of StatusDto objects.
    func convertToDtos(statusActivityPubEventItems: [StatusActivityPubEventItem], on context: ExecutionContext) async -> [StatusActivityPubEventItemDto]
    
    /// Determines if a user can view a status.
    ///
    /// - Parameters:
    ///   - status: The status to check.
    ///   - userId: The user identifier (optional).
    ///   - context: The execution context for database and services.
    /// - Returns: True if the user can view the status; otherwise false.
    /// - Throws: An error if the check fails.
    func can(view status: Status, userId: Int64?, on context: ExecutionContext) async throws -> Bool
    
    /// Retrieves the original status given a status Id.
    ///
    /// - Parameters:
    ///   - id: The status identifier.
    ///   - database: The database to query against.
    /// - Returns: The original ``Status`` or nil if not found.
    /// - Throws: An error if the database query fails.
    func getOrginalStatus(id: Int64, on database: Database) async throws -> Status?
    
    /// Retrieves a reblogged status for a user and status Id.
    ///
    /// - Parameters:
    ///   - id: The original status identifier.
    ///   - userId: The user identifier.
    ///   - database: The database to query against.
    /// - Returns: The reblogged ``Status`` or nil if not found.
    /// - Throws: An error if the database query fails.
    func getReblogStatus(id: Int64, userId: Int64, on database: Database) async throws -> Status?
    
    /// Retrieves the main status in a chain of comments.
    ///
    /// - Parameters:
    ///   - id: The status identifier.
    ///   - database: The database to query against.
    /// - Returns: The main ``Status`` if found; otherwise nil.
    /// - Throws: An error if the database query fails.
    func getMainStatus(for: Int64?, on database: Database) async throws -> Status?
    
    /// Deletes all statuses owned by a user.
    ///
    /// - Parameters:
    ///   - userId: The user identifier.
    ///   - context: The execution context for database and services.
    /// - Throws: An error if any deletion fails.
    func delete(owner userId: Int64, on context: ExecutionContext) async throws
    
    /// Deletes a status by its identifier.
    ///
    /// - Parameters:
    ///   - statusId: The internal identifier of the status to delete.
    ///   - database: The database to delete from.
    /// - Throws: An error if deletion fails.
    func delete(id statusId: Int64, on database: Database) async throws
    
    /// Deletes a remote status given its ActivityPub Id and related identifiers.
    ///
    /// - Parameters:
    ///   - statusActivityPubId: The ActivityPub ID of the status.
    ///   - userId: The user identifier requesting deletion.
    ///   - statusId: The internal status identifier.
    ///   - context: The execution context for database and services.
    /// - Throws: An error if deletion fails.
    func deleteFromRemote(statusActivityPubId: String, userId: Int64, statusId: Int64, on context: ExecutionContext) async throws

    /// Updates the reblogs count for the given status.
    ///
    /// - Parameters:
    ///   - statusId: The internal identifier of the status.
    ///   - database: The database to update.
    /// - Throws: An error if the update fails.
    func updateReblogsCount(for statusId: Int64, on database: Database) async throws

    /// Updates the favourites count for the given status.
    ///
    /// - Parameters:
    ///   - statusId: The internal identifier of the status.
    ///   - database: The database to update.
    /// - Throws: An error if the update fails.
    func updateFavouritesCount(for statusId: Int64, on database: Database) async throws

    /// Updates the replies count for the given status.
    ///
    /// - Parameters:
    ///   - statusId: The internal identifier of the status.
    ///   - database: The database to update.
    /// - Throws: An error if the update fails.
    func updateRepliesCount(for statusId: Int64, on database: Database) async throws
    
    /// Retrieves statuses for a user with pagination and filtering.
    ///
    /// - Parameters:
    ///   - userId: The user identifier.
    ///   - linkableParams: Pagination and filter parameters.
    ///   - context: The execution context for database and services.
    /// - Returns: A paginated result of statuses.
    /// - Throws: An error if the query fails.
    func statuses(for userId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<Status>
    
    /// Retrieves public statuses with pagination and filtering.
    ///
    /// - Parameters:
    ///   - linkableParams: Pagination and filter parameters.
    ///   - context: The execution context for database and services.
    /// - Returns: A paginated result of public statuses.
    /// - Throws: An error if the query fails.
    func statuses(linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<Status>
    
    /// Retrieves ancestor statuses in a comment chain.
    ///
    /// - Parameters:
    ///   - statusId: The status identifier.
    ///   - database: The database to query.
    /// - Returns: An array of ancestor statuses.
    /// - Throws: An error if the query fails.
    func ancestors(for statusId: Int64, on database: Database) async throws -> [Status]
    
    /// Retrieves descendant statuses in a comment chain.
    ///
    /// - Parameters:
    ///   - statusId: The status identifier.
    ///   - database: The database to query.
    /// - Returns: An array of descendant statuses.
    /// - Throws: An error if the query fails.
    func descendants(for statusId: Int64, on database: Database) async throws -> [Status]
    
    /// Retrieves a paginated list of users who have reblogged the specified status.
    ///
    /// - Parameters:
    ///   - statusId: The internal identifier of the status to check.
    ///   - linkableParams: Pagination and filter parameters.
    ///   - context: The execution context for database and services.
    /// - Returns: A paginated result containing users who reblogged the status.
    /// - Throws: An error if the query fails.
    func reblogged(statusId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<User>
    
    /// Retrieves a paginated list of users who have favourited the specified status.
    ///
    /// - Parameters:
    ///   - statusId: The internal identifier of the status to check.
    ///   - linkableParams: Pagination and filter parameters.
    ///   - context: The execution context for database and services.
    /// - Returns: A paginated result containing users who favourited the status.
    /// - Throws: An error if the query fails.
    func favourited(statusId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<User>
    
    /// Removes a status from all user timelines.
    ///
    /// - Parameters:
    ///   - statusId: The status identifier.
    ///   - database: The database to update.
    /// - Throws: An error if the operation fails.
    func unlist(statusId: Int64, on database: Database) async throws
    
    /// Extracts status mentions from a note string.
    ///
    /// - Parameters:
    ///   - statusId: The status identifier.
    ///   - note: The content string to parse mentions from (optional).
    ///   - context: The execution context for database and services.
    /// - Returns: An array of StatusMention objects.
    func getStatusMentions(statusId: Int64, note: String?, on context: ExecutionContext) async -> [StatusMention]
    
    /// Extracts status hashtags from a note string.
    ///
    /// - Parameters:
    ///   - statusId: The status identifier.
    ///   - note: The content string to parse hashtags from (optional).
    ///   - context: The execution context for database and services.
    /// - Returns: An array of StatusHashtag objects.
    func getStatusHashtags(statusId: Int64, note: String?, on context: ExecutionContext) async -> [StatusHashtag]
}

/// A service for managing statuses in the system.
final class StatusesService: StatusesServiceType {
    
    func get(activityPubId: String, on database: Database) async throws -> Status? {
        return try await Status.query(on: database)
            .with(\.$user)
            .group(.or) { group in
                group
                    .filter(\.$activityPubId == activityPubId)
                    .filter(\.$activityPubUrl == activityPubId)
            }
            .first()
    }
    
    func get(id: Int64, on database: Database) async throws -> Status? {
        return try await Status.query(on: database)
            .filter(\.$id == id)
            .with(\.$user)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$emojis)
            .with(\.$category)
            .first()
    }
    
    func all(userId: Int64, on database: Database) async throws -> [Status] {
        return try await Status.query(on: database)
            .filter(\.$user.$id == userId)
            .with(\.$user)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$emojis)
            .with(\.$category)
            .all()
    }
    
    func get(ids: [Int64], on database: Database) async throws -> [Status] {
        return try await Status.query(on: database)
            .filter(\.$id ~~ ids)
            .with(\.$user)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$emojis)
            .with(\.$category)
            .all()
    }
    
    func count(for userId: Int64, on database: Database) async throws -> Int {
        return try await Status.query(on: database).filter(\.$user.$id == userId).count()
    }
    
    func count(onlyComments: Bool, on database: Database) async throws -> Int {
        var query = Status.query(on: database)
            .filter(\.$reblog.$id == nil)
            .filter(\.$isLocal == true)
                   
        if onlyComments {
            query = query.filter(\.$replyToStatus.$id != nil)
        } else {
            query = query.filter(\.$replyToStatus.$id == nil)
        }
        
        return try await query.count()
    }
    
    func get(history id: Int64, on database: Database) async throws -> [StatusHistory] {
        return try await StatusHistory.query(on: database)
            .filter(\.$orginalStatus.$id == id)
            .with(\.$user)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$emojis)
            .with(\.$category)
            .sort(\.$createdAt, .descending)
            .all()
    }
    
    func note(basedOn status: Status, replyToStatus: Status?, on context: ExecutionContext) async throws -> NoteDto {
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        
        let applicationSettings = context.settings.cached
        let baseAddress = applicationSettings?.baseAddress ?? ""

        let hashtags = status.hashtags.map({ NoteTagDto(from: $0, baseAddress: baseAddress) })
        let mentions = try await self.getNoteMentions(statusMentions: status.mentions, on: context)

        let categories: [NoteTagDto] = if let category = status.category {
            [NoteTagDto(category: category.name, baseAddress: baseAddress)]
        } else {
            []
        }
        
        let tags = hashtags + mentions + categories

        let cc = self.createCc(status: status, replyToStatus: replyToStatus)
        let to = self.createTo(status: status, replyToStatus: replyToStatus)
        
        // Sort and map attachments connected with status.
        let attachmentDtos = status.attachments.sorted().map({ MediaAttachmentDto(from: $0, baseImagesPath: baseImagesPath) })
        
        let userNameMaps = status.mentions.toDictionary()
        let noteHtml = status.note?.html(baseAddress: baseAddress, wrapInParagraph: true, userNameMaps: userNameMaps)
        let published = status.isLocal ? status.createdAt?.toISO8601String() : (status.publishedAt?.toISO8601String() ?? status.createdAt?.toISO8601String())
        let updated = status.updatedByUserAt ?? status.createdAt != status.updatedAt ? status.updatedAt?.toISO8601String() : nil
        
        let noteDto = NoteDto(id: status.activityPubId,
                              summary: status.contentWarning,
                              inReplyTo: replyToStatus?.activityPubId,
                              published: published,
                              updated: updated,
                              url: status.activityPubUrl,
                              attributedTo: status.user.activityPubProfile,
                              to: to,
                              cc: cc,
                              sensitive: status.sensitive,
                              atomUri: nil,
                              inReplyToAtomUri: nil,
                              conversation: nil,
                              content: noteHtml,
                              attachment: attachmentDtos,
                              tag: .multiple(tags))
        
        return noteDto
    }
    
    func updateStatusCount(for userId: Int64, on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }

        // Update total status counter.
        try await sql.raw("""
            UPDATE \(ident: User.schema)
            SET \(ident: "statusesCount") = (SELECT count(1) FROM \(ident: Status.schema) WHERE \(ident: "userId") = \(bind: userId))
            WHERE \(ident: "id") = \(bind: userId)
        """).run()
        
        // Update statuses with photos.
        try await sql.raw("""
            UPDATE \(ident: User.schema)
            SET \(ident: "photosCount") = (SELECT count(1) FROM (SELECT DISTINCT \(ident: "statusId") FROM \(ident: Attachment.schema) WHERE \(ident: "userId") = \(bind: userId) AND \(ident: "statusId") IS NOT NULL) AS \(ident: "sub"))
            WHERE \(ident: "id") = \(bind: userId)
        """).run()
    }
    
    func send(status statusId: Int64, on context: ExecutionContext) async throws {
        guard let status = try await self.get(id: statusId, on: context.application.db) else {
            throw Abort(.notFound)
        }
        
        // When status is response for other status (comment) we are sending the notification to parent status owner.
        let replyToStatusId = status.$replyToStatus.id
        if let replyToStatusId {
            try await self.notifyOwnerAboutComment(toStatusId: replyToStatusId, by: status.user.requireID(), on: context)
        }
        
        switch status.visibility {
        case .public, .followers:
            if let replyToStatusId {
                // Comments have to be send to orginal status user followers or orginal status remote server.
                guard let commentedStatus = try await self.get(id: replyToStatusId, on: context.application.db) else {
                    break
                }
                
                // We have to get first status in the tree.
                let mainStatus = try await self.getMainStatus(for: replyToStatusId, on: context.application.db)
                let firstStatus = mainStatus ?? commentedStatus
                
                if firstStatus.isLocal {
                    // Comments have to be send to the same servers where orginal status has been send,
                    // and to all users which already commented the status.
                    try await self.scheduleStatusSend(status: status,
                                                      mainStatus: mainStatus,
                                                      sharedInbox: nil,
                                                      followersOf: firstStatus.user.requireID(),
                                                      type: .create,
                                                      on: context)
                } else {
                    // When orginal status is from remote server we have to send comment only to this remote server,
                    // and to all users which already commented the status.
                    try await self.scheduleStatusSend(status: status,
                                                      mainStatus: mainStatus,
                                                      sharedInbox: firstStatus.user.sharedInbox,
                                                      followersOf: nil,
                                                      type: .create,
                                                      on: context)
                }
            } else {
                // Create status on owner tineline.
                let ownerUserStatusId = context.application.services.snowflakeService.generate()
                let ownerUserStatus = try UserStatus(id: ownerUserStatusId, type: .owner, userId: status.user.requireID(), statusId: statusId)
                try await ownerUserStatus.create(on: context.application.db)
                
                // Create statuses on local followers timeline.
                try await self.createOnLocalTimeline(followersOf: status.user.requireID(), status: status, on: context)
                
                // Create mention notifications.
                try await self.createMentionNotifications(status: status, on: context)
                
                // Create statuses (with images) on remote followers timeline.
                try await self.scheduleStatusSend(status: status,
                                                  mainStatus: nil,
                                                  sharedInbox: nil,
                                                  followersOf: status.user.requireID(),
                                                  type: .create,
                                                  on: context)
            }
        case .mentioned:
            if replyToStatusId == nil {
                let userIds = try await self.getMentionedUsers(for: status, on: context)
                for userId in userIds {
                    let newUserStatusId = context.application.services.snowflakeService.generate()
                    let userStatus = UserStatus(id: newUserStatusId, type: .mention, userId: userId, statusId: statusId)
                    try await userStatus.create(on: context.application.db)
                }
            }
        }
    }
    
    func send(update statusId: Int64, on context: ExecutionContext) async throws {
        guard let status = try await self.get(id: statusId, on: context.application.db) else {
            throw Abort(.notFound)
        }
        
        // Send notifications about update to local users who boosted the status.
        try await sendUpdateNotifications(for: status, on: context)
                
        switch status.visibility {
        case .public, .followers:            
            // Update statuses (with images) on remote followers timeline.
            try await self.scheduleStatusSend(status: status,
                                              mainStatus: nil,
                                              sharedInbox: nil,
                                              followersOf: status.user.requireID(),
                                              type: .update,
                                              on: context)
        case .mentioned:
            break
        }
    }
    
    func send(reblog statusId: Int64, on context: ExecutionContext) async throws {
        guard let status = try await self.get(id: statusId, on: context.application.db) else {
            throw Abort(.notFound)
        }
        
        switch status.visibility {
        case .public, .followers:
            // Create reblogged statuses on local followers timeline.
            try await self.createOnLocalTimeline(followersOf: status.user.requireID(), status: status, on: context)
            
            // Create mention notifications.
            try await self.createMentionNotifications(status: status, on: context)
            
            // Create reblogged statuses on remote followers timeline.
            try await self.scheduleAnnounceSend(status: status, followersOf: status.user.requireID(), on: context)
        case .mentioned:
            break
        }
    }
    
    func send(unreblog activityPubUnreblog: ActivityPubUnreblogDto, on context: ExecutionContext) async throws {
        guard let orginalStatus = try await self.get(id: activityPubUnreblog.orginalStatusId, on: context.db) else {
            throw Abort(.notFound)
        }
        
        switch orginalStatus.visibility {
        case .public, .followers:
            try await self.scheduleUnannounceSend(activityPubUnreblog: activityPubUnreblog, on: context)
        case .mentioned:
            break
        }
    }
    
    func send(favourite statusFavouriteId: Int64, on context: ExecutionContext) async throws {
        let statusFavourite = try await StatusFavourite.query(on: context.db)
            .filter(\.$id == statusFavouriteId)
            .with(\.$user)
            .with(\.$status) { status in
                status.with(\.$user)
            }
            .first()
        
        guard let statusFavourite else {
            throw Abort(.notFound)
        }
                
        switch statusFavourite.status.visibility {
        case .public, .followers:
            // Create favourite statuses on remote servers.
            try await self.scheduleFavouriteSend(statusFavourite: statusFavourite, on: context)
        case .mentioned:
            break
        }
    }
    
    func send(unfavourite statusFavouriteDto: StatusUnfavouriteJobDto, on context: ExecutionContext) async throws {
        let status = try await Status.query(on: context.db)
            .filter(\.$id == statusFavouriteDto.statusId)
            .with(\.$user)
            .first()
        
        guard let status else {
            throw Abort(.notFound)
        }
        
        let user = try await User.query(on: context.db)
            .filter(\.$id == statusFavouriteDto.userId)
            .first()
        
        guard let user else {
            throw Abort(.notFound)
        }
                
        switch status.visibility {
        case .public, .followers:
            // Create favourite statuses on remote servers.
            try await self.scheduleUnfavouriteSend(statusFavouriteId: statusFavouriteDto.statusFavouriteId, user: user, status: status, on: context)
        case .mentioned:
            break
        }
    }

    func create(basedOn noteDto: NoteDto, userId: Int64, on context: ExecutionContext) async throws -> Status {
        
        // First we need to check if status with same activityPubId already exists in the database.
        let statusFromDatabase = try await self.get(activityPubId: noteDto.id, on: context.db)
        if let statusFromDatabase {
            context.logger.info("Status '\(noteDto.url)' already exists in the database.")
            return statusFromDatabase
        }
        
        var replyToStatus: Status? = nil
        if let replyToActivityPubId = noteDto.inReplyTo {
            context.logger.info("Downloading commented status '\(replyToActivityPubId)' from local database.")
            replyToStatus = try await self.get(activityPubId: replyToActivityPubId, on: context.application.db)

            if replyToStatus == nil {
                context.logger.info("Status '\(replyToActivityPubId)' cannot found in local database. Adding comment has been terminated.")
                throw StatusError.cannotAddCommentWithoutCommentedStatus
            }
        }
        
        var savedAttachments: [Attachment] = []
        if let attachments = noteDto.attachment {
            for (index, attachment) in attachments.enumerated() {
                if let attachmentEntity = try await self.saveAttachment(attachment: attachment, userId: userId, order: index, on: context) {
                    savedAttachments.append(attachmentEntity)
                }
            }
        }
        
        let userNames = noteDto.tag?.mentions() ?? []
        let hashtags = noteDto.tag?.hashtags() ?? []
        let emojis = noteDto.tag?.emojis() ?? []
        let categories = noteDto.tag?.categories() ?? []
        
        context.logger.info("Downloading emojis (count: \(emojis.count)) for status '\(noteDto.url)' to application storage.")
        let downloadedEmojis = try await self.downloadEmojis(emojis: emojis, on: context)
        
        // We can save also main status when we are adding new comment.
        let mainStatus = try await self.getMainStatus(for: replyToStatus?.id, on: context.db)
        
        let category = try await self.getCategory(basedOn: hashtags, and: categories, on: context.application.db)
        let newStatusId = context.application.services.snowflakeService.generate()
        
        let status = Status(id: newStatusId,
                            isLocal: false,
                            userId: userId,
                            note: noteDto.content ?? "",
                            activityPubId: noteDto.id,
                            activityPubUrl: noteDto.url,
                            application: nil,
                            categoryId: category?.id,
                            visibility: replyToStatus?.visibility ?? .public,
                            sensitive: noteDto.sensitive ?? false,
                            contentWarning: noteDto.summary,
                            replyToStatusId: replyToStatus?.id,
                            mainReplyToStatusId: mainStatus?.id ?? replyToStatus?.id,
                            publishedAt: noteDto.published?.fromISO8601String())

        let attachmentsFromDatabase = savedAttachments
        let replyToStatusFromDatabase = replyToStatus
        
        let statusHashtags = try await getStatusHashtags(status: status, hashtags: hashtags, on: context)
        let statusMentions = try await getStatusMentions(status: status, userNames: userNames, on: context)
        
        context.logger.info("Saving status '\(noteDto.url)' in the database.")
        try await context.application.db.transaction { database in
            // Save status in database.
            try await status.save(on: database)
            
            // Connect attachments with new status.
            for attachment in attachmentsFromDatabase {
                attachment.$status.id = status.id
                try await attachment.save(on: database)
            }
            
            // Create hashtags based on note.
            for statusHashtag in statusHashtags {
                try await statusHashtag.save(on: database)
            }
            
            // Create mentions based on note.
            for statusMention in statusMentions {
                try await statusMention.save(on: database)
            }
            
            // Create emojis based on note.
            for emoji in emojis {
                if let emojiId = emoji.id, let fileName = downloadedEmojis[emojiId] {
                    // Create and save emoji entity.
                    let newStatusEmojiId = context.application.services.snowflakeService.generate()
                    let statusEmoji = try StatusEmoji(id: newStatusEmojiId,
                                                      statusId: status.requireID(),
                                                      activityPubId: emojiId,
                                                      name: emoji.name,
                                                      mediaType: emoji.icon?.mediaType ?? fileName.mimeType ?? "image/png",
                                                      fileName: fileName)

                    try await statusEmoji.save(on: database)
                }
            }
            
            // We have to update number of statuses replies.
            if let replyToStatusId = replyToStatusFromDatabase?.id {
                try await self.updateRepliesCount(for: replyToStatusId, on: database)
            }
            
            context.logger.info("Status '\(noteDto.url)' saved in the database.")
        }
        
        // We can add notification to user about new comment/mention.
        if let replyToStatus, let statusFromDatabase = try await self.get(id: status.requireID(), on: context.application.db) {
            // We have to download ancestors when favourited is comment (in notifications screen we can show main photo which is commented).
            let mainStatus = try await self.getMainStatus(for: statusFromDatabase.id, on: context.db)
            
            let notificationsService = context.application.services.notificationsService
            try await notificationsService.create(type: .newComment,
                                                  to: replyToStatus.user,
                                                  by: statusFromDatabase.user.requireID(),
                                                  statusId: replyToStatus.requireID(),
                                                  mainStatusId: mainStatus?.id,
                                                  on: context)

            context.logger.info("Notification (mention) about new comment to user '\(replyToStatus.user.activityPubProfile)' added to database.")
        }
        
        return status
    }
    
    func create(basedOn statusRequestDto: StatusRequestDto, user: User, on request: Request) async throws -> Status {
        let userId = try user.requireID()

        // Verify attachments ids.
        var attachments: [Attachment] = []
        for attachmentId in statusRequestDto.attachmentIds {
            guard let attachmentId = attachmentId.toId() else {
                throw StatusError.incorrectAttachmentId
            }
            
            let attachment = try await Attachment.query(on: request.db)
                .filter(\.$id == attachmentId)
                .filter(\.$user.$id == userId)
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
        
        // We can save also main status when we are adding new comment.
        let statusesService = request.application.services.statusesService
        let mainStatus = try await statusesService.getMainStatus(for: statusRequestDto.replyToStatusId?.toId(), on: request.db)
        
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        let attachmentsFromDatabase = attachments
        let statusId = request.application.services.snowflakeService.generate()

        let status = Status(id: statusId,
                            isLocal: true,
                            userId: userId,
                            note: statusRequestDto.note,
                            baseAddress: baseAddress,
                            userName: user.userName,
                            application: request.applicationName,
                            categoryId: statusRequestDto.categoryId?.toId(),
                            visibility: statusRequestDto.visibility.translate(),
                            sensitive: statusRequestDto.sensitive,
                            contentWarning: statusRequestDto.contentWarning,
                            commentsDisabled: statusRequestDto.commentsDisabled,
                            replyToStatusId: statusRequestDto.replyToStatusId?.toId(),
                            mainReplyToStatusId: mainStatus?.id ?? statusRequestDto.replyToStatusId?.toId(),
                            publishedAt: Date())
        
        let statusMentions = try await statusesService.getStatusMentions(statusId: status.requireID(), note: status.note, on: request.executionContext)
        let statusHashtags = try await statusesService.getStatusHashtags(statusId: status.requireID(), note: status.note, on: request.executionContext)
        
        // Save status and attachments into database (in one transaction).
        try await request.db.transaction { database in
            try await status.create(on: database)
            
            for (index, attachment) in attachmentsFromDatabase.enumerated() {
                attachment.$status.id = status.id
                attachment.order = index

                try await attachment.save(on: database)
            }
            
            for statusHashtag in statusHashtags {
                try await statusHashtag.save(on: database)
            }
            
            for statusMention in statusMentions {
                try await statusMention.save(on: database)
            }
            
            // We have to update number of user's statuses counter.
            try await request.application.services.statusesService.updateStatusCount(for: userId, on: database)
            
            // We have to update number of statuses replies.
            if let replyToStatusId = statusRequestDto.replyToStatusId?.toId() {
                try await request.application.services.statusesService.updateRepliesCount(for: replyToStatusId, on: database)
            }
        }
        
        let statusFromDatabase = try await request.application.services.statusesService.get(id: status.requireID(), on: request.db)
        guard let statusFromDatabase else {
            throw EntityNotFoundError.statusNotFound
        }
        
        return statusFromDatabase
    }
    
    func update(status: Status, basedOn noteDto: NoteDto, on context: ExecutionContext) async throws -> Status {
        // Copy status data to history table.
        let newStatusHistoryId = context.application.services.snowflakeService.generate()
        let statusHistory = try StatusHistory(id: newStatusHistoryId, from: status)

        var exifHistories: [ExifHistory] = []
        let attachmentHistories = status.attachments.map {
            let newAttachmentHistoryId = context.application.services.snowflakeService.generate()

            if let exif = $0.exif {
                let newExifHistoryId = context.application.services.snowflakeService.generate()
                let exifHistory = ExifHistory(id: newExifHistoryId, attachmentHistoryId: newAttachmentHistoryId, from: exif)
                exifHistories.append(exifHistory)
            }
            
            return AttachmentHistory(id: newAttachmentHistoryId, statusHistoryId: newStatusHistoryId, from: $0)
        }
        
        let statusHashtagHistories = status.hashtags.map {
            let newStatusHashtagHistoryId = context.application.services.snowflakeService.generate()
            return StatusHashtagHistory(id: newStatusHashtagHistoryId, statusHistoryId: newStatusHistoryId, from: $0)
        }

        let statusMentionHistories = status.mentions.map {
            let newStatusMentionHistoryId = context.application.services.snowflakeService.generate()
            return StatusMentionHistory(id: newStatusMentionHistoryId, statusHistoryId: newStatusHistoryId, from: $0)
        }

        let statusEmojiHistories = status.emojis.map {
            let newStatusEmojiHistoryId = context.application.services.snowflakeService.generate()
            return StatusEmojiHistory(id: newStatusEmojiHistoryId, statusHistoryId: newStatusHistoryId, from: $0)
        }
        
        let userNames = noteDto.tag?.mentions() ?? []
        let hashtags = noteDto.tag?.hashtags() ?? []
        let emojis = noteDto.tag?.emojis() ?? []
        let categories = noteDto.tag?.categories() ?? []
        
        let statusHashtags = try await getStatusHashtags(status: status, hashtags: hashtags, on: context)
        let statusMentions = try await getStatusMentions(status: status, userNames: userNames, on: context)
        let category = try await self.getCategory(basedOn: hashtags, and: categories, on: context.application.db)
        
        context.logger.info("Downloading emojis (count: \(emojis.count)) for status '\(noteDto.url)' to application storage.")
        let downloadedEmojis = try await self.downloadEmojis(emojis: emojis, on: context)
                
        var savedAttachments: [Attachment] = []
        if let attachments = noteDto.attachment {
            for (index, attachment) in attachments.enumerated() {
                if let attachmentEntity = try await self.saveAttachment(attachment: attachment, userId: status.$user.id, order: index, on: context) {
                    savedAttachments.append(attachmentEntity)
                }
            }
        }
        
        context.logger.info("Saving status '\(noteDto.url)' in the database (with history).")
        let exifHistoriesToSave = exifHistories
        let attachmentsFromDatabase = savedAttachments
        
        try await context.application.db.transaction { database in
            // Save status history in database.
            try await statusHistory.save(on: database)
            
            // Save attachment histories with new status history.
            for attachmentHistory in attachmentHistories {
                try await attachmentHistory.save(on: database)
            }
            
            // Save attachment exif histories with new status history.
            for exifHistory in exifHistoriesToSave {
                try await exifHistory.save(on: database)
            }
            
            // Create hashtags histories.
            for statusHashtagHistory in statusHashtagHistories {
                try await statusHashtagHistory.save(on: database)
            }
            
            // Create mentions histories.
            for statusMentionHistory in statusMentionHistories {
                try await statusMentionHistory.save(on: database)
            }
            
            // Create emojis based on note.
            for statusEmojiHistory in statusEmojiHistories {
                try await statusEmojiHistory.save(on: database)
            }
            
            // Update data in orginal status table row.
            status.note = noteDto.content ?? ""
            status.sensitive = noteDto.sensitive ?? false
            status.contentWarning = noteDto.summary
            status.updatedByUserAt = noteDto.updated?.fromISO8601String() ?? Date()
            status.$category.id = category?.id
            
            // Save changes in orginal status.
            try await status.save(on: database)
            
            // Delete old attachments (clearing statusId, attachment will be deleted by bacground job).
            for attachment in status.attachments {
                attachment.$status.id = nil
                try await attachment.save(on: database)
            }
            
            // Connect attachments with new status.
            for attachment in attachmentsFromDatabase {
                attachment.$status.id = status.id
                try await attachment.save(on: database)
            }
            
            // Delete old hashtags.
            try await status.hashtags.delete(on: database)
            
            // Create hashtags based on note.
            for statusHashtag in statusHashtags {
                try await statusHashtag.save(on: database)
            }
            
            // Delete old mentions.
            try await status.mentions.delete(on: database)
            
            // Create mentions based on note.
            for statusMention in statusMentions {
                try await statusMention.save(on: database)
            }
            
            // Delete old emojis.
            try await status.emojis.delete(on: database)
            
            // Create emojis based on note.
            for emoji in emojis {
                if let emojiId = emoji.id, let fileName = downloadedEmojis[emojiId] {
                    // Create and save emoji entity.
                    let newStatusEmojiId = context.application.services.snowflakeService.generate()
                    let statusEmoji = try StatusEmoji(id: newStatusEmojiId,
                                                      statusId: status.requireID(),
                                                      activityPubId: emojiId,
                                                      name: emoji.name,
                                                      mediaType: emoji.icon?.mediaType ?? fileName.mimeType ?? "image/png",
                                                      fileName: fileName)

                    try await statusEmoji.save(on: database)
                }
            }
        }
        
        guard let statusAfterUpdate = try await self.get(id: status.requireID(), on: context.db) else {
            throw StatusError.incorrectStatusId
        }
        
        // Send notifications about update to users who boosted the status.
        try await sendUpdateNotifications(for: statusAfterUpdate, on: context)
        
        return statusAfterUpdate
    }
    
    func update(status: Status, basedOn statusRequestDto: StatusRequestDto, on request: Request) async throws -> Status {
        let snowflakeService = request.application.services.snowflakeService

        // Copy status data to history table.
        let newStatusHistoryId = snowflakeService.generate()
        let statusHistory = try StatusHistory(id: newStatusHistoryId, from: status)

        var exifHistories: [ExifHistory] = []
        let attachmentHistories = status.attachments.map {
            let newAttachmentHistoryId = snowflakeService.generate()

            if let exif = $0.exif {
                let newExifHistoryId = snowflakeService.generate()
                let exifHistory = ExifHistory(id: newExifHistoryId, attachmentHistoryId: newAttachmentHistoryId, from: exif)
                exifHistories.append(exifHistory)
            }
            
            return AttachmentHistory(id: newAttachmentHistoryId, statusHistoryId: newStatusHistoryId, from: $0)
        }
        
        let statusHashtagHistories = status.hashtags.map {
            let newStatusHashtagHistoryId = snowflakeService.generate()
            return StatusHashtagHistory(id: newStatusHashtagHistoryId, statusHistoryId: newStatusHistoryId, from: $0)
        }

        let statusMentionHistories = status.mentions.map {
            let newStatusMentionHistoryId = snowflakeService.generate()
            return StatusMentionHistory(id: newStatusMentionHistoryId, statusHistoryId: newStatusHistoryId, from: $0)
        }

        let statusEmojiHistories = status.emojis.map {
            let newStatusEmojiHistoryId = snowflakeService.generate()
            return StatusEmojiHistory(id: newStatusEmojiHistoryId, statusHistoryId: newStatusHistoryId, from: $0)
        }
        
        let statusHashtags = try await self.getStatusHashtags(statusId: status.requireID(), note: statusRequestDto.note, on: request.executionContext)
        let statusMentions = try await self.getStatusMentions(statusId: status.requireID(), note: statusRequestDto.note, on: request.executionContext)
        
        // Verify attachments ids.
        var attachments: [Attachment] = []
        for attachmentId in statusRequestDto.attachmentIds {
            guard let attachmentId = attachmentId.toId() else {
                throw StatusError.incorrectAttachmentId
            }
            
            let attachment = try await Attachment.query(on: request.db)
                .filter(\.$id == attachmentId)
                .filter(\.$user.$id == status.$user.id)
                .group(.or) { group in
                    group
                        .filter(\.$status.$id == nil)
                        .filter(\.$status.$id == status.id)
                }
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
                        
        request.logger.info("Saving status '\(status.stringId() ?? "")' in the database (with history).")
        let exifHistoriesToSave = exifHistories
        let attachmentsFromDatabase = attachments
        
        try await request.db.transaction { database in
            // Save status history in database.
            try await statusHistory.save(on: database)
            
            // Save attachment histories with new status history.
            for attachmentHistory in attachmentHistories {
                try await attachmentHistory.save(on: database)
            }
            
            // Save attachment exif histories with new status history.
            for exifHistory in exifHistoriesToSave {
                try await exifHistory.save(on: database)
            }
            
            // Create hashtags histories.
            for statusHashtagHistory in statusHashtagHistories {
                try await statusHashtagHistory.save(on: database)
            }
            
            // Create mentions histories.
            for statusMentionHistory in statusMentionHistories {
                try await statusMentionHistory.save(on: database)
            }
            
            // Create emojis based on note.
            for statusEmojiHistory in statusEmojiHistories {
                try await statusEmojiHistory.save(on: database)
            }
            
            // Update data in orginal status table row.
            status.note = statusRequestDto.note
            status.sensitive = statusRequestDto.sensitive
            status.contentWarning = statusRequestDto.contentWarning
            status.updatedByUserAt = Date()
            status.$category.id = statusRequestDto.categoryId?.toId()

            // Save changes in orginal status.
            try await status.save(on: database)
            
            // Delete old attachments (clearing statusId, attachment will be deleted by bacground job).
            for attachment in status.attachments {
                attachment.$status.id = nil
                try await attachment.save(on: database)
            }
            
            // Connect attachments with new status.            
            for (index, attachment) in attachmentsFromDatabase.enumerated() {
                attachment.$status.id = status.id
                attachment.order = index

                try await attachment.save(on: database)
            }
            
            // Delete old hashtags.
            try await status.hashtags.delete(on: database)
            
            // Create hashtags based on note.
            for statusHashtag in statusHashtags {
                try await statusHashtag.save(on: database)
            }
            
            // Delete old mentions.
            try await status.mentions.delete(on: database)
            
            // Create mentions based on note.
            for statusMention in statusMentions {
                try await statusMention.save(on: database)
            }
        }
        
        guard let statusAfterUpdate = try await self.get(id: status.requireID(), on: request.db) else {
            throw StatusError.incorrectStatusId
        }
        
        return statusAfterUpdate
    }
    
    func createOnLocalTimeline(followersOf userId: Int64, status: Status, on context: ExecutionContext) async throws {
        let size = 100
        var page = 0

        let reblogStatus: Status? = if let reblogId = status.$reblog.id {
            try await self.get(id: reblogId, on: context.db)
        } else {
            nil
        }
                
        while true {
            let result = try await Follow.query(on: context.db)
                .filter(\.$target.$id == userId)
                .filter(\.$approved == true)
                .join(User.self, on: \Follow.$source.$id == \User.$id)
                .filter(User.self, \.$isLocal == true)
                .sort(\.$id, .ascending)
                .paginate(PageRequest(page: page, per: size))
            
            if result.items.isEmpty {
                break
            }
            
            for follow in result.items {
                var shouldAddToUserTimeline = true
                let followerId = follow.$source.id
                
                let userMute = try await self.getUserMute(userId: followerId, mutedUserId: userId, on: context)
                
                // We shoudn't add status if it's status and user is muting statuses.
                if reblogStatus == nil && userMute.muteStatuses == true {
                    shouldAddToUserTimeline = false
                }
                
                // We shouldn't add status if it's a reblog and user is muting reblogs.
                if reblogStatus != nil && userMute.muteReblogs == true {
                    shouldAddToUserTimeline = false
                }
                
                // We shound't add status if it's a reblog of status of user who is muted.
                if let reblogStatus {
                    let reblogUserMute = try await self.getUserMute(userId: followerId, mutedUserId: reblogStatus.$user.id, on: context)
                    if reblogUserMute.muteStatuses == true {
                        shouldAddToUserTimeline = false
                    }
                }
                
                // Add to timeline only when picture has not been visible in the user's timeline before.
                let alreadyExistsInUserTimeline = await self.alreadyExistsInUserTimeline(userId: followerId, status: status, on: context)
                if alreadyExistsInUserTimeline {
                    shouldAddToUserTimeline = false
                }
                
                if shouldAddToUserTimeline {
                    let newUserStatusId = context.application.services.snowflakeService.generate()
                    let userStatus = try UserStatus(id: newUserStatusId,
                                                    type: reblogStatus != nil ? .reblog : .follow,
                                                    userId: followerId,
                                                    statusId: status.requireID())

                    try await userStatus.create(on: context.application.db)
                }
            }
            
            page += 1
        }
    }
    
    public func reblogged(statusId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<User> {
        var queryBuilder = Status.query(on: context.db)
            .with(\.$user) { user in
                user
                    .with(\.$flexiFields)
                    .with(\.$roles)
            }
            .filter(\.$reblog.$id == statusId)
        
        if let minId = linkableParams.minId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            queryBuilder = queryBuilder
                .sort(\.$createdAt, .descending)
        }
        
        let reblogs = try await queryBuilder
            .limit(linkableParams.limit)
            .all()
        
        let sortedReblogs = reblogs.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
                
        return LinkableResult(
            maxId: sortedReblogs.last?.stringId(),
            minId: sortedReblogs.first?.stringId(),
            data: sortedReblogs.map({ $0.user })
        )
    }
    
    public func favourited(statusId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<User> {
        var queryBuilder = StatusFavourite.query(on: context.db)
            .with(\.$user) { user in
                user
                    .with(\.$flexiFields)
                    .with(\.$roles)
            }
            .filter(\.$status.$id == statusId)
        
        if let minId = linkableParams.minId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            queryBuilder = queryBuilder
                .sort(\.$createdAt, .descending)
        }
        
        let reblogs = try await queryBuilder
            .limit(linkableParams.limit)
            .all()
        
        let sortedReblogs = reblogs.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
                
        return LinkableResult(
            maxId: sortedReblogs.last?.stringId(),
            minId: sortedReblogs.first?.stringId(),
            data: sortedReblogs.map({ $0.user })
        )
    }
    
    private func getUserMute(userId: Int64, mutedUserId: Int64, on context: ExecutionContext) async throws -> UserMute {
        let userMute = try await UserMute.query(on: context.db)
            .filter(\.$user.$id == userId)
            .filter(\.$mutedUser.$id == mutedUserId)
            .group(.or) { group in
                group
                    .filter(\.$muteEnd == nil)
                    .filter(\.$muteEnd > Date())
            }
            .first()
        
        if let userMute {
            return userMute
        }
        
        let id = context.services.snowflakeService.generate()
        return UserMute(id: id, userId: userId, mutedUserId: mutedUserId, muteStatuses: false, muteReblogs: false, muteNotifications: false)
    }
    
    private func alreadyExistsInUserTimeline(userId: Int64, status: Status, on context: ExecutionContext) async -> Bool {
        guard let orginalStatusId = status.$reblog.id ?? status.id else {
            return false
        }
        
        // Check if user alredy have orginal status (picture) on timeline (as orginal picture or reblogged).
        let statuses = try? await UserStatus.query(on: context.db)
            .join(Status.self, on: \UserStatus.$status.$id == \Status.$id)
            .filter(\.$user.$id == userId)
            .group(.or) { group in
                group
                    .filter(Status.self, \.$id == orginalStatusId)
                    .filter(Status.self, \.$reblog.$id == orginalStatusId)
            }
            .count()
        
        return (statuses ?? 0) > 0
    }
    
    /// Create notification about new comment to status (for comment/status owner only).
    private func notifyOwnerAboutComment(toStatusId: Int64, by userId: Int64, on context: ExecutionContext) async throws {
        guard let status = try await self.get(id: toStatusId, on: context.db) else {
            return
        }
        
        let mainStatus = try await self.getMainStatus(for: toStatusId, on: context.db)

        let notificationsService = context.services.notificationsService
        try await notificationsService.create(type: .newComment,
                                              to: status.user,
                                              by: userId,
                                              statusId: mainStatus?.id ?? status.id,
                                              mainStatusId: nil,
                                              on: context)
    }
    
    private func createMentionNotifications(status: Status, on context: ExecutionContext) async throws {
        for mention in status.mentions {
            let user = try await User.query(on: context.db)
                .group(.or) { group in
                    group
                        .filter(\.$userNameNormalized == mention.userNameNormalized)
                        .filter(\.$accountNormalized == mention.userNameNormalized)
                }
                .first()
                
            guard let user else {
                continue
            }
            
            // Create notification for mentioned user.
            let notificationsService = context.services.notificationsService
            try await notificationsService.create(type: .mention,
                                                  to: user,
                                                  by: status.$user.id,
                                                  statusId: status.requireID(),
                                                  mainStatusId: nil,
                                                  on: context)
        }
    }
    
    private func scheduleFavouriteSend(statusFavourite: StatusFavourite, on context: ExecutionContext) async throws {
        let sharedInbox = statusFavourite.status.user.sharedInbox
        guard let sharedInbox else {
            context.logger.warning("Favourite: '\(statusFavourite.stringId() ?? "")' cannot be send to shared inbox url: '\(sharedInbox ?? "")'.")
            return
        }

        // Create array with integration information.
        let snowflakeService = context.services.snowflakeService
        let statusId = try statusFavourite.status.requireID()
        let userId = try statusFavourite.user.requireID()
        let statusFavouriteId = statusFavourite.stringId()
        
        let newStatusActivityPubEventId = snowflakeService.generate()
        let statusActivityPubEvent = StatusActivityPubEvent(id: newStatusActivityPubEventId, statusId: statusId, userId: userId, type: .like)

        let newStatusActivityPubEventItemId = snowflakeService.generate()
        let statusActivityPubEventItem = StatusActivityPubEventItem(id: newStatusActivityPubEventItemId,
                                                                    statusActivityPubEventId: newStatusActivityPubEventId,
                                                                    url: sharedInbox)
        
        // Save integration information into database.
        try await context.db.transaction { database in
            try await statusActivityPubEvent.create(on: database)
            try await statusActivityPubEventItem.create(on: database)
        }

        // Dispatch new queue which will send real network requests to calculated inboxes.
        try await context
            .queues(.apStatus)
            .dispatch(ActivityPubStatusJob.self, ActivityPubStatusJobDataDto(statusActivityPubEventId: newStatusActivityPubEventId,
                                                                             statusFavouriteId: statusFavouriteId))
    }
    
    private func scheduleUnfavouriteSend(statusFavouriteId: String, user: User, status: Status, on context: ExecutionContext) async throws {
        let sharedInbox = status.user.sharedInbox
        guard let sharedInbox else {
            context.logger.warning("Unfavourite: '\(statusFavouriteId)' cannot be send to shared inbox url: '\(sharedInbox ?? "")'.")
            return
        }

        // Create array with integration information.
        let snowflakeService = context.services.snowflakeService
        let statusId = try status.requireID()
        let userId = try user.requireID()
        
        let newStatusActivityPubEventId = snowflakeService.generate()
        let statusActivityPubEvent = StatusActivityPubEvent(id: newStatusActivityPubEventId, statusId: statusId, userId: userId, type: .unlike)

        let newStatusActivityPubEventItemId = snowflakeService.generate()
        let statusActivityPubEventItem = StatusActivityPubEventItem(id: newStatusActivityPubEventItemId,
                                                                    statusActivityPubEventId: newStatusActivityPubEventId,
                                                                    url: sharedInbox)
        
        // Save integration information into database.
        try await context.db.transaction { database in
            try await statusActivityPubEvent.create(on: database)
            try await statusActivityPubEventItem.create(on: database)
        }

        // Dispatch new queue which will send real network requests to calculated inboxes.
        try await context
            .queues(.apStatus)
            .dispatch(ActivityPubStatusJob.self, ActivityPubStatusJobDataDto(statusActivityPubEventId: newStatusActivityPubEventId,
                                                                             statusFavouriteId: statusFavouriteId))
    }
    
    private func scheduleStatusSend(status: Status,
                                    mainStatus: Status?,
                                    sharedInbox: String?,
                                    followersOf userId: Int64?,
                                    type: StatusActivityPubEventType,
                                    on context: ExecutionContext) async throws {
        // Sometimes we have additional shared inbox where we have to send status (like main author of the commented status).
        let commonSharedInbox: [String] = if let sharedInbox { [sharedInbox] } else { [] }
        
        // Calculate followers shared inboxes.
        let followersSharedInboxes = try await self.getFollowersOfSharedInboxes(followersOf: userId, on: context)
        
        // Calculate commentators shared inboxes.
        let commentatorsSharedInboxes = try await self.getCommentatorsSharedInboxes(statusId: mainStatus?.requireID(), on: context)
        
        // All combined shared inboxes.
        let sharedInboxesSet = Set(commonSharedInbox + followersSharedInboxes + commentatorsSharedInboxes)
        
        // Create array with integration information.
        let snowflakeService = context.services.snowflakeService
        let statusId = try status.requireID()
        let userId = try status.user.requireID()
        
        let newStatusActivityPubEventId = snowflakeService.generate()
        let statusActivityPubEvent = StatusActivityPubEvent(id: newStatusActivityPubEventId, statusId: statusId, userId: userId, type: type)

        let statusActivityPubEventItems = sharedInboxesSet.map {
            let newStatusActivityPubEventItemId = snowflakeService.generate()
            return StatusActivityPubEventItem(id: newStatusActivityPubEventItemId, statusActivityPubEventId: newStatusActivityPubEventId, url: $0)
        }
        
        // Save integration information into database.
        try await context.db.transaction { database in
            try await statusActivityPubEvent.create(on: database)
            try await statusActivityPubEventItems.create(on: database)
        }

        // Dispatch new queue which will send real network requests to calculated inboxes.
        try await context
            .queues(.apStatus)
            .dispatch(ActivityPubStatusJob.self, ActivityPubStatusJobDataDto(statusActivityPubEventId: newStatusActivityPubEventId))
    }
    
    private func getCommentatorsSharedInboxes(statusId: Int64?, on context: ExecutionContext) async throws -> [String] {
        guard let statusId else {
            return []
        }
        
        let commentators = try await Status.query(on: context.db)
            .filter(\.$mainReplyToStatus.$id == statusId)
            .join(User.self, on: \Status.$user.$id == \User.$id)
            .filter(User.self, \.$isLocal == false)
            .field(User.self, \.$sharedInbox)
            .unique()
            .all()
        
        let sharedInboxes = try commentators.map({ try $0.joined(User.self).sharedInbox })
        return sharedInboxes.compactMap { $0 }
    }
    
    private func getFollowersOfSharedInboxes(followersOf userId: Int64?, on context: ExecutionContext) async throws -> [String] {
        guard let userId else {
            return []
        }
        
        let follows = try await Follow.query(on: context.application.db)
            .filter(\.$target.$id == userId)
            .filter(\.$approved == true)
            .join(User.self, on: \Follow.$source.$id == \User.$id)
            .filter(User.self, \.$isLocal == false)
            .field(User.self, \.$sharedInbox)
            .unique()
            .all()
                
        let sharedInboxes = try follows.map({ try $0.joined(User.self).sharedInbox })
        return sharedInboxes.compactMap { $0 }
    }
    
    private func scheduleAnnounceSend(status: Status, followersOf userId: Int64, on context: ExecutionContext) async throws {
        guard let reblogStatusId = status.$reblog.id else {
            context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be announce to shared inbox. Missing reblogId property.")
            return
        }
        
        guard let reblogStatus = try await Status.query(on: context.db)
            .filter(\.$id == reblogStatusId)
            .with(\.$user)
            .first() else {
            context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be announce to shared inbox. Missing reblog status with id: '\(reblogStatusId)'.")
            return
        }
        
        // Calculate followers shared inboxes.
        let followersSharedInboxes = try await self.getFollowersOfSharedInboxes(followersOf: userId, on: context)
        
        // Create array with integration information.
        let snowflakeService = context.services.snowflakeService
        let userId = try status.user.requireID()
        
        let newStatusActivityPubEventId = snowflakeService.generate()
        let statusActivityPubEvent = StatusActivityPubEvent(id: newStatusActivityPubEventId, statusId: reblogStatusId, userId: userId, type: .announce)
        
        let statusActivityPubEventItems = followersSharedInboxes.map {
            let newStatusActivityPubEventItemId = snowflakeService.generate()
            return StatusActivityPubEventItem(id: newStatusActivityPubEventItemId, statusActivityPubEventId: newStatusActivityPubEventId, url: $0)
        }
        
        // Save integration information into database.
        try await context.db.transaction { database in
            try await statusActivityPubEvent.create(on: database)
            try await statusActivityPubEventItems.create(on: database)
        }

        // Create DTO with announce information used to reblog.
        let activityPubReblog = ActivityPubReblogDto(activityPubStatusId: status.activityPubId,
                                                     activityPubProfile: status.user.activityPubProfile,
                                                     published: status.createdAt ?? Date(),
                                                     activityPubReblogProfile: reblogStatus.user.activityPubProfile,
                                                     activityPubReblogStatusId: reblogStatus.activityPubId)
        
        // Dispatch new queue which will send real network requests to calculated inboxes.
        try await context
            .queues(.apStatus)
            .dispatch(ActivityPubStatusJob.self, ActivityPubStatusJobDataDto(statusActivityPubEventId: newStatusActivityPubEventId,
                                                                             activityPubReblog: activityPubReblog))
    }
    
    private func scheduleUnannounceSend(activityPubUnreblog: ActivityPubUnreblogDto, on context: ExecutionContext) async throws {
        // Calculate followers shared inboxes.
        let followersSharedInboxes = try await self.getFollowersOfSharedInboxes(followersOf: activityPubUnreblog.userId, on: context)
        
        // Create array with integration information.
        let snowflakeService = context.services.snowflakeService
        let statusId = activityPubUnreblog.orginalStatusId
        let userId = activityPubUnreblog.userId
        
        let newStatusActivityPubEventId = snowflakeService.generate()
        let statusActivityPubEvent = StatusActivityPubEvent(id: newStatusActivityPubEventId, statusId: statusId, userId: userId, type: .unannounce)
        
        let statusActivityPubEventItems = followersSharedInboxes.map {
            let newStatusActivityPubEventItemId = snowflakeService.generate()
            return StatusActivityPubEventItem(id: newStatusActivityPubEventItemId, statusActivityPubEventId: newStatusActivityPubEventId, url: $0)
        }
        
        // Save integration information into database.
        try await context.db.transaction { database in
            try await statusActivityPubEvent.create(on: database)
            try await statusActivityPubEventItems.create(on: database)
        }

        // Dispatch new queue which will send real network requests to calculated inboxes.
        try await context
            .queues(.apStatus)
            .dispatch(ActivityPubStatusJob.self, ActivityPubStatusJobDataDto(statusActivityPubEventId: newStatusActivityPubEventId,
                                                                             activityPubUnreblog: activityPubUnreblog))
    }
    
    func convertToDtos(statuses: [Status], on context: ExecutionContext) async -> [StatusDto] {
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        let baseAddress = context.settings.cached?.baseAddress ?? ""

        let reblogIds = statuses.compactMap { $0.$reblog.id }
        let reblogStatuses = try? await self.get(ids: reblogIds, on: context.db)
        
        let allStatusIds = statuses.compactMap { $0.id } + reblogIds
        let favouritedStatuses = try? await self.statusesAreFavourited(statusIds: allStatusIds, on: context)
        let rebloggedStatuses = try? await self.statusesAreReblogged(statusIds: allStatusIds, on: context)
        let bookmarkedStatuses = try? await self.statusesAreBookmarked(statusIds: allStatusIds, on: context)
        let featuredStatuses = try? await self.statusesAreFeatured(statusIds: allStatusIds, on: context)
                
        let statusDtos = await statuses.asyncMap { status in
            var reblogDto: StatusDto? = nil
            if let reblogStatus = reblogStatuses?.first(where: { $0.id == status.$reblog.id }) {
                
                // Sort and map attachments placed in rebloged status.
                let reblogAttachmentDtos = reblogStatus.attachments.sorted().map({ AttachmentDto(from: $0, baseImagesPath: baseImagesPath) })
                let userNameMaps = status.mentions.toDictionary()

                reblogDto = StatusDto(from: reblogStatus,
                                      userNameMaps: userNameMaps,
                                      baseAddress: baseAddress,
                                      baseImagesPath: baseImagesPath,
                                      attachments: reblogAttachmentDtos,
                                      reblog: nil,
                                      isFavourited: favouritedStatuses?.contains(where: { $0 == reblogStatus.id }) ?? false,
                                      isReblogged: rebloggedStatuses?.contains(where: { $0 == reblogStatus.id }) ?? false,
                                      isBookmarked: bookmarkedStatuses?.contains(where: { $0 == reblogStatus.id }) ?? false,
                                      isFeatured: featuredStatuses?.contains(where: { $0 == reblogStatus.id }) ?? false)
            }
            
            // Sort and map attachment in status.
            let attachmentDtos = status.attachments.sorted().map({ AttachmentDto(from: $0, baseImagesPath: baseImagesPath) })
            let userNameMaps = status.mentions.toDictionary()

            return StatusDto(from: status,
                             userNameMaps: userNameMaps,
                             baseAddress: baseAddress,
                             baseImagesPath: baseImagesPath,
                             attachments: attachmentDtos,
                             reblog: reblogDto,
                             isFavourited: favouritedStatuses?.contains(where: { $0 == status.id }) ?? false,
                             isReblogged: rebloggedStatuses?.contains(where: { $0 == status.id }) ?? false,
                             isBookmarked: bookmarkedStatuses?.contains(where: { $0 == status.id }) ?? false,
                             isFeatured: featuredStatuses?.contains(where: { $0 == status.id }) ?? false)
        }
        
        return statusDtos
    }
    
    func convertToDto(status: Status, attachments: [Attachment], attachUserInteractions: Bool, on context: ExecutionContext) async -> StatusDto {
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        let baseAddress = context.settings.cached?.baseAddress ?? ""

        let attachmentDtos = attachments.sorted().map({ AttachmentDto(from: $0, baseImagesPath: baseImagesPath) })
        let userNameMaps = status.mentions.toDictionary()
        
        let isFavourited = attachUserInteractions ? (try? await self.statusIsFavourited(statusId: status.requireID(), on: context)) : nil
        let isReblogged = attachUserInteractions ? (try? await self.statusIsReblogged(statusId: status.requireID(), on: context)) : nil
        let isBookmarked = attachUserInteractions ? (try? await self.statusIsBookmarked(statusId: status.requireID(), on: context)) : nil
        let isFeatured = attachUserInteractions ? (try? await self.statusIsFeatured(statusId: status.requireID(), on: context)) : nil
        
        var reblogDto: StatusDto?
        if let reblogId = status.$reblog.id,
           let reblog = try? await self.get(id: reblogId, on: context.db) {
            reblogDto = await self.convertToDto(status: reblog, attachments: reblog.attachments, attachUserInteractions: attachUserInteractions, on: context)
        }
        
        return StatusDto(from: status,
                         userNameMaps: userNameMaps,
                         baseAddress: baseAddress,
                         baseImagesPath: baseImagesPath,
                         attachments: attachmentDtos,
                         reblog: reblogDto,
                         isFavourited: isFavourited ?? false,
                         isReblogged: isReblogged ?? false,
                         isBookmarked: isBookmarked ?? false,
                         isFeatured: isFeatured ?? false)
    }
    
    func convertToDtos(statusHistories: [StatusHistory], on context: ExecutionContext) async -> [StatusDto] {
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        let baseAddress = context.settings.cached?.baseAddress ?? ""
                
        let statusDtos = statusHistories.map { statusHistory in
            // Sort and map attachment in status.
            let attachmentDtos = statusHistory.attachments.sorted().map({ AttachmentDto(from: $0, baseImagesPath: baseImagesPath) })
            let userNameMaps = statusHistory.mentions.toDictionary()

            return StatusDto(from: statusHistory,
                             userNameMaps: userNameMaps,
                             baseAddress: baseAddress,
                             baseImagesPath: baseImagesPath,
                             attachments: attachmentDtos,
                             reblog: nil,
                             isFavourited: false,
                             isReblogged: false,
                             isBookmarked: false,
                             isFeatured: false)
        }
        
        return statusDtos
    }
    
    func convertToDtos(statusActivityPubEvents: [StatusActivityPubEvent], on context: ExecutionContext) async -> [StatusActivityPubEventDto] {
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        let baseAddress = context.settings.cached?.baseAddress ?? ""
                
        let statusActivityPubEventDtos = statusActivityPubEvents.map { statusActivityPubEvent in
            return StatusActivityPubEventDto(id: statusActivityPubEvent.stringId(),
                                             user: UserDto(from: statusActivityPubEvent.user, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
                                             statusId: "\(statusActivityPubEvent.$status.id)",
                                             type: StatusActivityPubEventTypeDto.from(statusActivityPubEvent.type),
                                             result: StatusActivityPubEventResultDto.from(statusActivityPubEvent.result),
                                             errorMessage: statusActivityPubEvent.errorMessage,
                                             attempts: statusActivityPubEvent.attempts,
                                             startAt: statusActivityPubEvent.startAt,
                                             endAt: statusActivityPubEvent.endAt,
                                             createdAt: statusActivityPubEvent.createdAt,
                                             updatedAt: statusActivityPubEvent.updatedAt,
                                             statusActivityPubEventItems: nil
            )
        }
        
        return statusActivityPubEventDtos
    }
    
    func convertToDtos(statusActivityPubEventItems: [StatusActivityPubEventItem], on context: ExecutionContext) async -> [StatusActivityPubEventItemDto] {                
        let statusActivityPubEventItemDtos = statusActivityPubEventItems.map { statusActivityPubEventItem in
            return StatusActivityPubEventItemDto(
                id: statusActivityPubEventItem.stringId(),
                url: statusActivityPubEventItem.url,
                isSuccess: statusActivityPubEventItem.isSuccess,
                errorMessage: statusActivityPubEventItem.errorMessage,
                startAt: statusActivityPubEventItem.startAt,
                endAt: statusActivityPubEventItem.endAt,
                createdAt: statusActivityPubEventItem.createdAt,
                updatedAt: statusActivityPubEventItem.updatedAt
            )
        }
        
        return statusActivityPubEventItemDtos
    }
    
    func can(view status: Status, userId: Int64?, on context: ExecutionContext) async throws -> Bool {
        // These statuses can see all of the people over the internet.
        if status.visibility == .public || status.visibility == .followers {
            return true
        }
        
        // If user is not authorized, theb he cannot see the statuses other then public/followers.
        guard let userId else {
            return false
        }
        
        // When user is owner of the status.
        if status.user.id == userId {
            return true
        }
        
        // For mentioned visibility we have to check if user has been connected with status.
        if try await UserStatus.query(on: context.db)
            .filter(\.$status.$id == status.requireID())
            .filter(\.$user.$id == userId)
            .first() != nil {
            return true
        }
        
        return false
    }
    
    func getOrginalStatus(id: Int64, on database: Database) async throws -> Status? {
        let status = try await self.get(id: id, on: database)
        guard let status else {
            return nil
        }

        guard let reblogId = status.$reblog.id else {
            return status
        }
        
        return try await self.get(id: reblogId, on: database)
    }
    
    func getReblogStatus(id: Int64, userId: Int64, on database: Database) async throws -> Status? {
        let status = try await Status.query(on: database)
            .filter(\.$id == id)
            .filter(\.$user.$id == userId)
            .first()
        
        // We have already reblog status Id.
        if let status, status.$reblog.id != nil {
            return try await self.get(id: status.requireID(), on: database)
        }
        
        // If not we have to get status which reblogs status by the user.
        let reblog = try await Status.query(on: database)
            .filter(\.$reblog.$id == id)
            .filter(\.$user.$id == userId)
            .first()
        
        guard let reblog else {
            return nil
        }
        
        return try await self.get(id: reblog.requireID(), on: database)
    }
    
    /// Function is returning main status in chain of the comments. When status is already main status then nil is returned.
    func getMainStatus(for id: Int64?, on database: Database) async throws -> Status? {
        guard let id else {
            return nil
        }
        
        let ancestors = try await self.ancestors(for: id, on: database)
        return ancestors.first
    }
    
    func updateReblogsCount(for statusId: Int64, on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }

        try await sql.raw("""
            UPDATE \(ident: Status.schema)
            SET \(ident: "reblogsCount") = (SELECT count(1) FROM \(ident: Status.schema) WHERE \(ident: "reblogId") = \(bind: statusId))
            WHERE \(ident: "id") = \(bind: statusId)
        """).run()
    }
    
    func updateFavouritesCount(for statusId: Int64, on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }

        try await sql.raw("""
            UPDATE \(ident: Status.schema)
            SET \(ident: "favouritesCount") = (SELECT count(1) FROM \(ident: StatusFavourite.schema) WHERE \(ident: "statusId") = \(bind: statusId))
            WHERE \(ident: "id") = \(bind: statusId)
        """).run()
    }
    
    func updateRepliesCount(for statusId: Int64, on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }

        try await sql.raw("""
            UPDATE \(ident: Status.schema)
            SET \(ident: "repliesCount") = (SELECT count(1) FROM \(ident: Status.schema) WHERE \(ident: "replyToStatusId") = \(bind: statusId))
            WHERE \(ident: "id") = \(bind: statusId)
        """).run()
    }
    
    func delete(owner userId: Int64, on context: ExecutionContext) async throws {
        let statuses = try await Status.query(on: context.db)
            .filter(\.$user.$id == userId)
            .field(\.$id)
            .all()
        
        var errorOccurred = false
        for status in statuses {
            do {
                try await self.delete(id: status.requireID(), on: context.db)
            } catch {
                errorOccurred = true
                await context.logger.store("Failed to delete status: '\(status.stringId() ?? "<unkown>")'.", error, on: context.application)
            }
        }
        
        if errorOccurred {
            throw StatusError.cannotDeleteStatus
        }
    }
    
    func delete(id statusId: Int64, on database: Database) async throws {
        let status = try await Status.query(on: database)
            .filter(\.$id == statusId)
            .with(\.$attachments) { attachment in
                attachment.with(\.$exif)
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$originalHdrFile)
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$emojis)
            .first()
        
        guard let status else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to delete all statuses that reblogged this status.
        let reblogs = try await Status.query(on: database)
            .filter(\.$reblog.$id == statusId)
            .all()
        
        // We have to delete all replies for this status.
        let replies = try await Status.query(on: database)
            .filter(\.$replyToStatus.$id == statusId)
            .all()

        // We have to delete status from all users timelines.
        let statusTimelines = try await UserStatus.query(on: database)
            .filter(\.$status.$id == statusId)
            .all()
        
        // We have to delete all status featured.
        let statusFeatured = try await FeaturedStatus.query(on: database)
            .filter(\.$status.$id == statusId)
            .all()
        
        // We have to delete all status reports.
        let statusReports = try await Report.query(on: database)
            .filter(\.$status.$id == statusId)
            .all()
        
        // We have to delete all status bookmarks.
        let statusBookmarks = try await StatusBookmark.query(on: database)
            .filter(\.$status.$id == statusId)
            .all()
        
        // We have to delete all status favourites.
        let statusFavourites = try await StatusFavourite.query(on: database)
            .filter(\.$status.$id == statusId)
            .all()
        
        // We have to delete from trending statuses.
        let statusTrending = try await TrendingStatus.query(on: database)
            .filter(\.$status.$id == statusId)
            .all()
        
        // We have to delete all notifications which mention that status.
        let notifications = try await Notification.query(on: database)
            .filter(\.$status.$id == statusId)
            .all()
        
        // We have to delete all status histories.
        let statusHistories = try await StatusHistory.query(on: database)
            .filter(\.$orginalStatus.$id == statusId)
            .all()

        let statusHistoryIds = try statusHistories.map { try $0.requireID() }
        let attachmentHistories = try await AttachmentHistory.query(on: database)
            .filter(\.$statusHistory.$id ~~ statusHistoryIds)
            .all()
        
        let hashtagHistories = try await StatusHashtagHistory.query(on: database)
            .filter(\.$statusHistory.$id ~~ statusHistoryIds)
            .all()
        
        let mentionHistories = try await StatusMentionHistory.query(on: database)
            .filter(\.$statusHistory.$id ~~ statusHistoryIds)
            .all()

        let emojiHistories = try await StatusEmojiHistory.query(on: database)
            .filter(\.$statusHistory.$id ~~ statusHistoryIds)
            .all()
        
        // We have to delete notification markers which points to notification to delete.
        // Maybe in the future we can figure out something more clever.
        let notificationIds = try notifications.map { try $0.requireID() }
        let notificationMarkers = try await NotificationMarker.query(on: database)
            .filter(\.$notification.$id ~~ notificationIds)
            .all()
        
        // Delete all status ActivityPub events connected with status.
        let statusActivityPubEvents = try await StatusActivityPubEvent.query(on: database)
            .filter(\.$status.$id == statusId)
            .all()
        let statusActivityPubEventIds = try statusActivityPubEvents.map { try $0.requireID() }
        
        try await database.transaction { transaction in
            // Delete all status ActivityPub event items connected with event connected with status.
            try await StatusActivityPubEventItem.query(on: transaction)
                .filter(\.$statusActivityPubEvent.$id ~~ statusActivityPubEventIds)
                .delete()
            
            // Delete all status ActivityPub events connected with status.
            try await statusActivityPubEvents.delete(on: transaction)
            
            // We are disconnecting attachment histories from the status history. Attachment and files will be deleted by ClearAttachmentsJob.
            for attachmentHisotry in attachmentHistories {
                attachmentHisotry.$statusHistory.id = nil
                try await attachmentHisotry.save(on: transaction)
            }
            
            // First we need to delete all status histories children.
            try await emojiHistories.delete(on: transaction)
            try await mentionHistories.delete(on: transaction)
            try await hashtagHistories.delete(on: transaction)
            
            // We deleted all histories children, now we can delete status histories.
            try await statusHistories.delete(on: transaction)
            
            // We are disconnecting attachment from the status. Attachment and files will be deleted by ClearAttachmentsJob.
            for attachment in status.attachments {
                attachment.$status.id = nil
                try await attachment.save(on: transaction)
            }

            try await reblogs.asyncForEach { reblog in
                try await self.delete(id: reblog.requireID(), on: transaction)
            }
            
            try await replies.asyncForEach { reply in
                try await self.delete(id: reply.requireID(), on: transaction)
            }

            try await statusTimelines.delete(on: transaction)
            try await statusFeatured.delete(on: transaction)
            try await statusReports.delete(on: transaction)
            try await statusBookmarks.delete(on: transaction)
            try await statusFavourites.delete(on: transaction)
            try await statusTrending.delete(on: transaction)
            
            try await notificationMarkers.delete(on: transaction)
            try await notifications.delete(on: transaction)
            
            try await status.hashtags.delete(on: transaction)
            try await status.mentions.delete(on: transaction)
            try await status.emojis.delete(on: transaction)
            try await status.delete(on: transaction)
        }
        
        // We have to update number of user's statuses counter.
        try await self.updateStatusCount(for: status.$user.id, on: database)
        
        // We have to update number of statuses replies.
        if let replyToStatusId = status.$replyToStatus.id {
            try await self.updateRepliesCount(for: replyToStatusId, on: database)
        }
    }
    
    func deleteFromRemote(statusActivityPubId: String, userId: Int64, statusId: Int64, on context: ExecutionContext) async throws {
        guard let user = try await User.query(on: context.db)
            .filter(\.$id == userId)
            .withDeleted()
            .first() else {
            context.logger.warning("User: '\(userId)' cannot exists in database.")
            return
        }

        guard let privateKey = user.privateKey else {
            context.logger.warning("Status: '\(statusActivityPubId)' cannot be send to shared inbox (delete). Missing private key.")
            return
        }
        
        let users = try await User.query(on: context.db)
            .filter(\.$isLocal == false)
            .field(\.$sharedInbox)
            .unique()
            .all()
        
        // All shared inboxes.
        let allSharedInboxes = users.map({  $0.sharedInbox })
        
        // Calculate followers shared inboxes.
        let followersSharedInboxes = try await self.getFollowersOfSharedInboxes(followersOf: userId, on: context)
        
        // Calculate commentators shared inboxes.
        let commentatorsSharedInboxes = try await self.getCommentatorsSharedInboxes(statusId: statusId, on: context)
        
        // All combined shared inboxes.
        let sharedInboxesSet = Array(followersSharedInboxes + commentatorsSharedInboxes + allSharedInboxes).unique()
        
        for (index, sharedInbox) in sharedInboxesSet.enumerated() {
            guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
                context.logger.warning("Status delete: '\(statusActivityPubId)' cannot be send to shared inbox url: '\(sharedInbox ?? "")'.")
                continue
            }

            context.logger.info("[\(index + 1)/\(sharedInboxesSet.count)] Sending status delete: '\(statusActivityPubId)' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
            
            do {
                try await activityPubClient.delete(actorId: user.activityPubProfile, statusId: statusActivityPubId, on: sharedInboxUrl)
            } catch {
                await context.logger.store("Sending status delete to shared inbox error. Shared inbox url: \(sharedInboxUrl).", error, on: context.application)
            }
        }
    }
    
    func statuses(for userId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<Status> {
        var query = Status.query(on: context.db)
            .group(.or) { group in
                group
                    .filter(\.$visibility ~~ [.public])
                    .filter(\.$user.$id == userId)
            }
            .sort(\.$createdAt, .descending)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$user)
            
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        } else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        } else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let statuses = try await query
            .limit(linkableParams.limit)
            .all()
        
        return LinkableResult(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statuses
        )
    }
    
    func statuses(linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<Status> {
        var query = Status.query(on: context.db)
            .filter(\.$visibility ~~ [.public])
            .sort(\.$createdAt, .descending)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$category)
            .with(\.$user)
            
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let statuses = try await query
            .limit(linkableParams.limit)
            .all()
        
        return LinkableResult(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statuses
        )
    }
    
    func ancestors(for statusId: Int64, on database: Database) async throws -> [Status] {
        guard let currentStatus = try await Status.query(on: database)
            .filter(\.$id == statusId)
            .first() else {
            return []
        }
        
        guard let replyToStatusId = currentStatus.$replyToStatus.id else {
            return []
        }
        
        var list: [Status] = [];
        var currentReplyToStatusId: Int64? = replyToStatusId
        
        while let currentStatudId = currentReplyToStatusId {
            if let ancestor = try await self.get(id: currentStatudId, on: database) {
                list.insert(ancestor, at: 0)
                currentReplyToStatusId = ancestor.$replyToStatus.id
            } else {
                currentReplyToStatusId = nil
            }
        }
        
        return list
    }
    
    func descendants(for statusId: Int64, on database: Database) async throws -> [Status] {
        var statuses = try await Status.query(on: database)
            .filter(\.$replyToStatus.$id == statusId)
            .with(\.$user)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$category)
            .with(\.$user)
            .sort(\.$createdAt, .ascending)
            .all()
        
        for status in statuses {
            let subStatuses = try await descendants(for: status.requireID(), on: database)
            statuses = statuses + subStatuses
        }
        
        return statuses
    }
    
    func unlist(statusId: Int64, on database: Database) async throws {
        try await UserStatus.query(on: database)
            .filter(\.$status.$id == statusId)
            .delete()
    }
    
    func getStatusMentions(statusId: Int64, note: String?, on context: ExecutionContext) async -> [StatusMention] {
        let searchService = context.services.searchService
        let userNames = note?.getUserNames() ?? []
        var statusMentions: [StatusMention] = []
        
        for userName in userNames {
            let newStatusMentionId = context.services.snowflakeService.generate()
            
            let user = try? await searchService.downloadRemoteUser(userName: userName, on: context)
            let statusMention = StatusMention(id: newStatusMentionId, statusId: statusId, userName: userName, userUrl: user?.url)
            statusMentions.append(statusMention)
        }
        
        return statusMentions
    }
    
    func getStatusHashtags(statusId: Int64, note: String?, on context: ExecutionContext) async -> [StatusHashtag] {
        let hashtags = note?.getHashtags() ?? []
        var statusHashtags: [StatusHashtag] = []
        
        for hashtag in hashtags {
            let newStatusHastagId = context.services.snowflakeService.generate()
            let statusHashtag = StatusHashtag(id: newStatusHastagId, statusId: statusId, hashtag: hashtag)
            statusHashtags.append(statusHashtag)
        }
        
        return statusHashtags
    }
        
    private func statusIsReblogged(statusId: Int64, on context: ExecutionContext) async throws -> Bool {
        guard let authorizationPayloadId = context.userId else {
            return false
        }
        
        let amountOfStatuses = try await Status.query(on: context.db)
            .filter(\.$reblog.$id == statusId)
            .filter(\.$user.$id == authorizationPayloadId)
            .count()
        
        return amountOfStatuses > 0
    }
    
    private func statusesAreReblogged(statusIds: [Int64], on context: ExecutionContext) async throws -> [Int64] {
        guard let authorizationPayloadId = context.userId else {
            return []
        }
        
        let rebloggedStatuses = try await Status.query(on: context.db)
            .filter(\.$reblog.$id ~~ statusIds)
            .filter(\.$user.$id == authorizationPayloadId)
            .field(\.$reblog.$id)
            .all()
        
        return rebloggedStatuses.compactMap({ $0.$reblog.id })
    }
    
    private func statusIsFavourited(statusId: Int64, on context: ExecutionContext) async throws -> Bool {
        guard let authorizationPayloadId = context.userId else {
            return false
        }
        
        let amountOfFavourites = try await StatusFavourite.query(on: context.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .count()
        
        return amountOfFavourites > 0
    }
    
    private func statusesAreFavourited(statusIds: [Int64], on context: ExecutionContext) async throws -> [Int64] {
        guard let authorizationPayloadId = context.userId else {
            return []
        }
        
        let favouritedStatuses = try await StatusFavourite.query(on: context.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id ~~ statusIds)
            .field(\.$status.$id)
            .all()
        
        return favouritedStatuses.map({ $0.$status.id })
    }
    
    private func statusIsBookmarked(statusId: Int64, on context: ExecutionContext) async throws -> Bool {
        guard let authorizationPayloadId = context.userId else {
            return false
        }
        
        let amountOfBookmarks = try await StatusBookmark.query(on: context.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .count()
        
        return amountOfBookmarks > 0
    }
    
    private func statusesAreBookmarked(statusIds: [Int64], on context: ExecutionContext) async throws -> [Int64] {
        guard let authorizationPayloadId = context.userId else {
            return []
        }
        
        let bookmarkedStatuses = try await StatusBookmark.query(on: context.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id ~~ statusIds)
            .field(\.$status.$id)
            .all()
        
        return bookmarkedStatuses.map({ $0.$status.id })
    }
    
    private func statusIsFeatured(statusId: Int64, on context: ExecutionContext) async throws -> Bool {
        let amount = try await FeaturedStatus.query(on: context.db)
            .filter(\.$status.$id == statusId)
            .count()
        
        return amount > 0
    }
    
    private func statusesAreFeatured(statusIds: [Int64], on context: ExecutionContext) async throws -> [Int64] {
        guard let authorizationPayloadId = context.userId else {
            return []
        }
        
        let featuredStatuses = try await FeaturedStatus.query(on: context.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id ~~ statusIds)
            .field(\.$status.$id)
            .all()
        
        return featuredStatuses.map({ $0.$status.id })
    }
    
    private func getMentionedUsers(for status: Status, on context: ExecutionContext) async throws -> [Int64] {
        var userIds: [Int64] = []
        
        for mention in status.mentions {
            let user = try await User.query(on: context.db)
                .group(.or) { group in
                    group
                        .filter(\.$userNameNormalized == mention.userNameNormalized)
                        .filter(\.$accountNormalized == mention.userNameNormalized)
                }
                .filter(\.$isLocal == true)
                .first()
            
            guard let user else {
                continue
            }
            
            try userIds.append(user.requireID())
        }
        
        return userIds
    }
    
    func getCategory(basedOn hashtags: [NoteTagDto], and categories: [NoteTagDto], on database: Database) async throws -> Category? {
        // First we can return category base on it's name.
        if let category = categories.first {
            let categoryNormalized = category.name.uppercased().trimmingCharacters(in: [" "])
            if let categoryFromDatabase = try await Category.query(on: database)
                .filter(\.$nameNormalized == categoryNormalized)
                .first() {
                return categoryFromDatabase
            }
        }
        
        // When we cannot find category based on the name (from tag) then we can calculate based on the hashtags.
        let hashtagString = hashtags.map { $0.name }
        return try await getCategory(basedOn: hashtagString, on: database)
    }
    
    private func getCategory(basedOn hashtags: [String], on database: Database) async throws -> Category? {
        guard hashtags.count > 0 else {
            return nil
        }
        
        let hashtagsNormalized = hashtags.map { $0.uppercased().replacingOccurrences(of: "#", with: "").trimmingCharacters(in: [" "]) }
        let categoryQuery = try await Category.query(on: database)
            .join(CategoryHashtag.self, on: \Category.$id == \CategoryHashtag.$category.$id)
            .filter(CategoryHashtag.self, \.$hashtagNormalized ~~ hashtagsNormalized)
            .filter(Category.self, \.$isEnabled == true)
            .sort(Category.self, \.$priority, .ascending)
            .first()
        
        return categoryQuery
    }
    
    private func saveAttachment(attachment: MediaAttachmentDto, userId: Int64, order: Int, on context: ExecutionContext) async throws -> Attachment? {
        guard attachment.mediaType.starts(with: "image/") else {
            return nil
        }

        let temporaryFileService = context.services.temporaryFileService
        let storageService = context.services.storageService
        
        // Save image to temp folder.
        context.logger.info("Saving attachment '\(attachment.url)' to temporary folder.")
        let tmpOriginalFileUrl = try await temporaryFileService.save(url: attachment.url, toFolder: nil, on: context)
        
        // Create image in the memory.
        context.logger.info("Opening image '\(attachment.url)' in memory.")
        guard let image = Image.create(path: tmpOriginalFileUrl) else {
            throw AttachmentError.createResizedImageFailed
        }
        
        // Resize image.
        context.logger.info("Resizing image '\(attachment.url)'.")
        guard let resized = image.resizedTo(width: 800) else {
            throw AttachmentError.imageResizeFailed
        }
        
        // Get fileName from URL.
        let fileName = attachment.url.fileName
        
        let applicationSettings = context.settings.cached
        let imageQuality = applicationSettings?.imageQuality ?? Constants.imageQuality
        
        // Save resized image in temp folder.
        context.logger.info("Saving resized image '\(fileName)' in temporary folder.")
        let tmpSmallFileUrl = try temporaryFileService.temporaryPath(based: fileName, on: context)
        resized.write(to: tmpSmallFileUrl, quality: imageQuality)
        
        // Save original image.
        context.logger.info("Saving orginal image '\(tmpOriginalFileUrl)' in storage provider.")
        let savedOriginalFileName = try await storageService.save(fileName: fileName, url: tmpOriginalFileUrl, on: context)
        
        // Save small image.
        context.logger.info("Saving resized image '\(tmpSmallFileUrl)' in storage provider.")
        let savedSmallFileName = try await storageService.save(fileName: fileName, url: tmpSmallFileUrl, on: context)
        
        // Download and save original HDR image.
        let savedOriginalHdrFileName = try await downloadHdrOriginalImage(attachment: attachment, on: context)
        
        // Get location id.
        var locationId: Int64? = nil
        if let geonameId = attachment.location?.geonameId {
            locationId = try await Location.query(on: context.application.db).filter(\.$geonameId == geonameId).first()?.id
        }
        
        // Prepare obejct to save in database.
        let originalFileInfoId = context.application.services.snowflakeService.generate()
        let originalFileInfo = FileInfo(id: originalFileInfoId,
                                        fileName: savedOriginalFileName,
                                        width: image.size.width,
                                        height: image.size.height)
        
        let smallFileInfoId = context.application.services.snowflakeService.generate()
        let smallFileInfo = FileInfo(id: smallFileInfoId,
                                     fileName: savedSmallFileName,
                                     width: resized.size.width,
                                     height: resized.size.height)
        
        var originalHdrFileInfo: FileInfo?
        if let savedOriginalHdrFileName {
            let originalHdrFileInfoId = context.application.services.snowflakeService.generate()
            originalHdrFileInfo = FileInfo(id: originalHdrFileInfoId,
                                           fileName: savedOriginalHdrFileName,
                                           width: image.size.width,
                                           height: image.size.height)
        }
        
        let attachmentId = context.application.services.snowflakeService.generate()
        let attachmentEntity = try Attachment(id: attachmentId,
                                              userId: userId,
                                              originalFileId: originalFileInfo.requireID(),
                                              smallFileId: smallFileInfo.requireID(),
                                              originalHdrFileId: originalHdrFileInfo?.id,
                                              description: attachment.name,
                                              blurhash: attachment.blurhash,
                                              locationId: locationId,
                                              order: order)
        
        // Operation in database should be performed in one transaction.
        context.logger.info("Saving attachment '\(attachment.url)' in database.")
        try await context.application.db.transaction { database in
            try await originalFileInfo.save(on: database)
            try await smallFileInfo.save(on: database)
            try await attachmentEntity.save(on: database)
            
            let id = context.application.services.snowflakeService.generate()
            if let exifDto = attachment.exif,
               let exif = Exif(id: id,
                               make: exifDto.make,
                               model: exifDto.model,
                               lens: exifDto.lens,
                               createDate: exifDto.createDate,
                               focalLenIn35mmFilm: exifDto.focalLenIn35mmFilm,
                               fNumber: exifDto.fNumber,
                               exposureTime: exifDto.exposureTime,
                               photographicSensitivity: exifDto.photographicSensitivity,
                               film: exifDto.film,
                               latitude: exifDto.latitude,
                               longitude: exifDto.longitude,
                               flash: exifDto.flash,
                               focalLength: exifDto.focalLength) {
                try await attachmentEntity.$exif.create(exif, on: database)
            }
            
            context.logger.info("Attachment '\(attachment.url)' saved in database.")
        }
        
        // Remove temporary files.
        context.logger.info("Clearing attachment temporary files '\(attachment.url)' from temporary folder.")
        try await temporaryFileService.delete(url: tmpOriginalFileUrl, on: context)
        try await temporaryFileService.delete(url: tmpSmallFileUrl, on: context)
        
        return attachmentEntity
    }
    
    private func downloadHdrOriginalImage(attachment: MediaAttachmentDto, on context: ExecutionContext) async throws -> String? {
        guard let hdrImageUrl = attachment.hdrImageUrl else {
            return nil
        }
        
        let temporaryFileService = context.services.temporaryFileService
        let storageService = context.services.storageService
            
        context.logger.info("Saving attachment HDR image '\(hdrImageUrl)' to temporary folder.")
        let tmpOriginalHdrFileUrl = try await temporaryFileService.save(url: hdrImageUrl, toFolder: nil, on: context)
        
        context.logger.info("Saving orginal HDR image '\(tmpOriginalHdrFileUrl)' in storage provider.")
        let hdrFileName = tmpOriginalHdrFileUrl.lastPathComponent
        let savedOriginalHdrFileName = try await storageService.save(fileName: hdrFileName, url: tmpOriginalHdrFileUrl, on: context)
        
        context.logger.info("Removing attachment HDR image temporary file '\(hdrImageUrl)' from temporary folder.")
        try await temporaryFileService.delete(url: tmpOriginalHdrFileUrl, on: context)
        
        return savedOriginalHdrFileName
    }
    
    private func createCc(status: Status, replyToStatus: Status?) -> ComplexType<ActorDto> {
        if let replyToStatusActivityPubProfile = replyToStatus?.user.activityPubProfile,
           replyToStatusActivityPubProfile != status.user.activityPubProfile {
            
            // For reply statuses we are always sending 'Unlisted'. For that kind #Public have to be specified in the cc field,
            // "followers" have to be send in the "to" field.
            return .multiple([
                    ActorDto(id: "https://www.w3.org/ns/activitystreams#Public"),
                    ActorDto(id: replyToStatusActivityPubProfile)])
        }
        
        // For regular statuses #Public have "to" be specified in to field.
        return .multiple([ActorDto(id: "\(status.user.activityPubProfile)/followers")])
    }
    
    private func createTo(status: Status, replyToStatus: Status?) -> ComplexType<ActorDto> {
        if let replyToStatusActivityPubProfile = replyToStatus?.user.activityPubProfile,
           replyToStatusActivityPubProfile != status.user.activityPubProfile {
            
            // For reply statuses we are always sending 'Unlisted'. For that kind #Public have to be specified in the cc field,
            // "followers" have to be send in the "to" field.
            return .multiple([ActorDto(id: "\(status.user.activityPubProfile)/followers")])
        }
        
        // For regular statuses #Public have to be specified in "to" field.
        return .multiple([ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")])
    }
    
    private func downloadEmojis(emojis: [NoteTagDto], on context: ExecutionContext) async throws-> [String: String] {
        let storageService = context.application.services.storageService
        var downloadedEmojis: [String: String] =  [:]

        for emoji in emojis {
            if let url = emoji.icon?.url, let emojiId = emoji.id {
                let fileName = try await storageService.download(url: url, on: context)
                downloadedEmojis[emojiId] = fileName
            }
        }
        
        return downloadedEmojis
    }
    
    private func getNoteMentions(statusMentions: [StatusMention], on context: ExecutionContext) async throws -> [NoteTagDto] {
        var mentions: [NoteTagDto] = []
        for mention in statusMentions {
            let mentionedUser = try await User.query(on: context.db)
                .group(.or) { queryGroup in
                    queryGroup.filter(\.$userNameNormalized == mention.userNameNormalized)
                    queryGroup.filter(\.$accountNormalized == mention.userNameNormalized)
                }
                .first()

            if let mentionedUser {
                mentions.append(NoteTagDto(userName: mentionedUser.account, activityPubProfile: mentionedUser.activityPubProfile))
            }
        }
        
        return mentions
    }
    
    private func getStatusMentions(status: Status, userNames: [NoteTagDto], on context: ExecutionContext) async throws -> [StatusMention] {
        let searchService = context.services.searchService
        var statusMentions: [StatusMention] = []
        
        for userName in userNames {
            let newStatusMentionId = context.application.services.snowflakeService.generate()
            
            let user: User? = if let activityubProfile = userName.href {
                try? await searchService.downloadRemoteUser(activityPubProfile: activityubProfile, on: context)
            } else {
                nil
            }

            let statusMention = try StatusMention(id: newStatusMentionId, statusId: status.requireID(), userName: userName.name, userUrl: user?.url)
            statusMentions.append(statusMention)
        }
        
        return statusMentions
    }
    
    private func getStatusHashtags(status: Status, hashtags: [NoteTagDto], on context: ExecutionContext) async throws -> [StatusHashtag] {
        var statusHashtags: [StatusHashtag] = []

        for hashtag in hashtags {
            let newStatusHashtagId = context.application.services.snowflakeService.generate()
            let statusHashtag = try StatusHashtag(id: newStatusHashtagId, statusId: status.requireID(), hashtag: hashtag.name)
            statusHashtags.append(statusHashtag)
        }
        
        return statusHashtags
    }

    private func sendUpdateNotifications(for status: Status, on context: ExecutionContext) async throws {
        let statusesService = context.services.statusesService
        let notificationsService = context.services.notificationsService

        let size = 100
        var page = 0
        
        // We have to download ancestors when favourited is comment (in notifications screen we can show main photo which is favourited).
        let ancestors = try await statusesService.ancestors(for: status.requireID(), on: context.db)
        
        // We have to iterate by boosts and send update notifications.
        while true {
            let result = try await Status.query(on: context.db)
                .with(\.$user)
                .filter(\.$reblog.$id == status.requireID())
                .sort(\.$id, .ascending)
                .paginate(PageRequest(page: page, per: size))
            
            if result.items.isEmpty {
                break
            }

            for reblogStatus in result.items {
                try await notificationsService.create(type: .update,
                                                      to: reblogStatus.user,
                                                      by: status.user.requireID(),
                                                      statusId: status.requireID(),
                                                      mainStatusId: ancestors.first?.id,
                                                      on: context)
            }
            
            page += 1
        }
    }
}

