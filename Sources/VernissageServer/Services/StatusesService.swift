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
    func get(activityPubId: String, on database: Database) async throws -> Status?
    func get(id: Int64, on database: Database) async throws -> Status?
    func get(ids: [Int64], on database: Database) async throws -> [Status]
    func all(userId: Int64, on database: Database) async throws -> [Status]
    func count(for userId: Int64, on database: Database) async throws -> Int
    func count(onlyComments: Bool, on database: Database) async throws -> Int
    func note(basedOn status: Status, replyToStatus: Status?, on context: ExecutionContext) throws -> NoteDto
    func updateStatusCount(for userId: Int64, on database: Database) async throws
    func send(status statusId: Int64, on context: ExecutionContext) async throws
    func send(reblog statusId: Int64, on context: ExecutionContext) async throws
    func send(unreblog activityPubUnreblog: ActivityPubUnreblogDto, on context: ExecutionContext) async throws
    func send(favourite statusFavouriteId: Int64, on context: ExecutionContext) async throws
    func send(unfavourite statusFavouriteDto: StatusUnfavouriteJobDto, on context: ExecutionContext) async throws
    func create(basedOn noteDto: NoteDto, userId: Int64, on context: ExecutionContext) async throws -> Status
    func createOnLocalTimeline(followersOf userId: Int64, status: Status, on context: ExecutionContext) async throws
    func convertToDto(status: Status, attachments: [Attachment], attachUserInteractions: Bool, on context: ExecutionContext) async -> StatusDto
    func convertToDtos(statuses: [Status], on context: ExecutionContext) async -> [StatusDto]
    func can(view status: Status, authorizationPayloadId: Int64, on context: ExecutionContext) async throws -> Bool
    func getOrginalStatus(id: Int64, on database: Database) async throws -> Status?
    func getReblogStatus(id: Int64, userId: Int64, on database: Database) async throws -> Status?
    func delete(owner userId: Int64, on context: ExecutionContext) async throws
    func delete(id statusId: Int64, on database: Database) async throws
    func deleteFromRemote(statusActivityPubId: String, userId: Int64, on context: ExecutionContext) async throws
    func updateReblogsCount(for statusId: Int64, on database: Database) async throws
    func updateFavouritesCount(for statusId: Int64, on database: Database) async throws
    func statuses(for userId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<Status>
    func statuses(linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<Status>
    func ancestors(for statusId: Int64, on database: Database) async throws -> [Status]
    func descendants(for statusId: Int64, on database: Database) async throws -> [Status]
    func reblogged(statusId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<User>
    func favourited(statusId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<User>
    func unlist(statusId: Int64, on database: Database) async throws
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
    
    func note(basedOn status: Status, replyToStatus: Status?, on context: ExecutionContext) throws -> NoteDto {
        let baseStoragePath = context.services.storageService.getBaseStoragePath(on: context)
        
        let appplicationSettings = context.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""

        let hashtags = status.hashtags.map({NoteHashtagDto(from: $0, baseAddress: baseAddress)})
        let mentions = status.mentions.map({NoteHashtagDto(from: $0, baseAddress: baseAddress)})
        let tags = hashtags + mentions

        let noteDto = NoteDto(id: status.activityPubId,
                              summary: status.contentWarning,
                              inReplyTo: replyToStatus?.activityPubId,
                              published: status.createdAt?.toISO8601String(),
                              url: status.activityPubUrl,
                              attributedTo: status.user.activityPubProfile,
                              to: .multiple([
                                ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")
                              ]),
                              cc: .multiple([
                                ActorDto(id: "\(status.user.activityPubProfile)/followers")
                              ]),
                              sensitive: status.sensitive,
                              atomUri: nil,
                              inReplyToAtomUri: nil,
                              conversation: nil,
                              content: status.note?.html(baseAddress: baseAddress, wrapInParagraph: true),
                              attachment: status.attachments.map({ MediaAttachmentDto(from: $0, baseStoragePath: baseStoragePath) }),
                              tag: .multiple(tags))
        
        return noteDto
    }
    
    func updateStatusCount(for userId: Int64, on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }

        try await sql.raw("""
            UPDATE \(ident: User.schema)
            SET \(ident: "statusesCount") = (SELECT count(1) FROM \(ident: Status.schema) WHERE \(ident: "userId") = \(bind: userId))
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
                guard let previousStatus = try await self.get(id: replyToStatusId, on: context.application.db) else {
                    break
                }
                
                // We have to get first status in the tree.
                let ancestors = try await self.ancestors(for: replyToStatusId, on: context.application.db)
                let firstStatus = ancestors.first ?? previousStatus
                
                if firstStatus.isLocal {
                    // Comments have to be send to the same servers where orginal status has been send.
                    try await self.createOnRemoteTimeline(status: status, followersOf: firstStatus.user.requireID(), on: context)
                } else {
                    // When orginal status is from remote server we have to send comment only to this remote server.
                    try await self.createOnRemoteTimeline(status: status, sharedInbox: firstStatus.user.sharedInbox, on: context)
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
                try await self.createOnRemoteTimeline(status: status, followersOf: status.user.requireID(), on: context)
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
            try await self.createAnnoucmentsOnRemoteTimeline(status: status, followersOf: status.user.requireID(), on: context)
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
            try await self.deleteAnnoucmentsFromRemoteTimeline(activityPubUnreblog: activityPubUnreblog, on: context)
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
            try await self.createFavouriteOnRemoteServer(statusFavourite: statusFavourite, on: context)
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
            try await self.createUnfavouriteOnRemoteServer(statusFavouriteId: statusFavouriteDto.statusFavouriteId, user: user, status: status, on: context)
        case .mentioned:
            break
        }
    }
    
    func create(basedOn noteDto: NoteDto, userId: Int64, on context: ExecutionContext) async throws -> Status {
        
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
            for attachment in attachments {
                if let attachmentEntity = try await self.saveAttachment(attachment: attachment, userId: userId, on: context) {
                    savedAttachments.append(attachmentEntity)
                }
            }
        }
        
        let userNames = noteDto.tag?.mentions() ?? []
        let hashtags = noteDto.tag?.hashtags() ?? []

        let category = try await self.getCategory(basedOn: hashtags, on: context.application.db)
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
                            replyToStatusId: replyToStatus?.id)

        let attachmentsFromDatabase = savedAttachments
        
        context.logger.info("Saving status '\(noteDto.url)' in database.")
        try await context.application.db.transaction { database in
            // Save status in database.
            try await status.save(on: database)
            
            // Connect attachments with new status.
            for attachment in attachmentsFromDatabase {
                attachment.$status.id = status.id
                try await attachment.save(on: database)
            }
            
            // Create hashtags based on note.
            for hashtag in hashtags {
                let newStatusHashtagId = context.application.services.snowflakeService.generate()
                let statusHashtag = try StatusHashtag(id: newStatusHashtagId, statusId: status.requireID(), hashtag: hashtag.name)
                try await statusHashtag.save(on: database)
            }
            
            // Create mentions based on note.
            for userName in userNames {
                let newStatusMentionId = context.application.services.snowflakeService.generate()
                let statusMention = try StatusMention(id: newStatusMentionId, statusId: status.requireID(), userName: userName.name)
                try await statusMention.save(on: database)
            }
            
            context.logger.info("Status '\(noteDto.url)' saved in database.")
        }
        
        // We can add notification to user about new comment/mention.
        if let replyToStatus,
           let statusFromDatabase = try await self.get(id: status.requireID(), on: context.application.db) {
            
            let notificationsService = context.application.services.notificationsService
            try await notificationsService.create(type: .newComment,
                                                  to: replyToStatus.user,
                                                  by: statusFromDatabase.user.requireID(),
                                                  statusId: replyToStatus.requireID(),
                                                  on: context)

            context.logger.info("Notification (mention) about new comment to user '\(replyToStatus.user.activityPubProfile)' added to database.")
        }
        
        return status
    }
    
    func createOnLocalTimeline(followersOf userId: Int64, status: Status, on context: ExecutionContext) async throws {
        let isReblog = status.$reblog.id != nil
        
        try await Follow.query(on: context.db)
            .filter(\.$target.$id == userId)
            .filter(\.$approved == true)
            .join(User.self, on: \Follow.$source.$id == \User.$id)
            .filter(User.self, \.$isLocal == true)
            .chunk(max: 100) { follows in
                for follow in follows {
                    Task {
                        do {
                            switch follow {
                            case .success(let success):
                                var shouldAddToUserTimeline = true
                                let followerId = success.$source.id
                                
                                let userMute = try await self.getUserMute(userId: followerId, mutedUserId: userId, on: context)
                                
                                // We shoudn't add status if it's status and user is muting statuses.
                                if isReblog == false && userMute.muteStatuses == true {
                                    shouldAddToUserTimeline = false
                                }
                                
                                // We shouldn't add status if it's a reblog and user is muting reblogs.
                                if isReblog == true && userMute.muteReblogs == true {
                                    shouldAddToUserTimeline = false
                                }
                                
                                // Add to timeline only when picture has not been visible in the user's timeline before.
                                let alreadyExistsInUserTimeline = await self.alreadyExistsInUserTimeline(userId: followerId, status: status, on: context)
                                if alreadyExistsInUserTimeline {
                                    shouldAddToUserTimeline = false
                                }
                                
                                if shouldAddToUserTimeline {
                                    let newUserStatusId = context.application.services.snowflakeService.generate()
                                    let userStatus = try UserStatus(id: newUserStatusId,
                                                                    type: isReblog ? .reblog : .follow,
                                                                    userId: followerId,
                                                                    statusId: status.requireID())

                                    try await userStatus.create(on: context.application.db)
                                }
                            case .failure(let failure):
                                await context.logger.store("Status \(status.stringId() ?? "") cannot be added to the user.", failure, on: context.application)
                            }
                        } catch {
                            await context.logger.store("Status \(status.stringId() ?? "") cannot be added to the user.", error, on: context.application)
                        }
                    }
                }
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
        
        let ancestors = try await self.ancestors(for: toStatusId, on: context.db)

        let notificationsService = context.services.notificationsService
        try await notificationsService.create(type: .newComment,
                                              to: status.user,
                                              by: userId,
                                              statusId: ancestors.first?.requireID() ?? status.requireID(),
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
                                                  on: context)
        }
    }
    
    private func createFavouriteOnRemoteServer(statusFavourite: StatusFavourite, on context: ExecutionContext) async throws {
        guard let privateKey = try await User.query(on: context.db).filter(\.$id == statusFavourite.user.requireID()).first()?.privateKey else {
            context.logger.warning("Favourite: '\(statusFavourite.stringId() ?? "")' cannot be send to shared inbox. Missing private key for user '\(statusFavourite.user.stringId() ?? "")'.")
            return
        }
        
        let sharedInbox = statusFavourite.status.user.sharedInbox
        
        guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
            context.logger.warning("Favourite: '\(statusFavourite.stringId() ?? "")' cannot be send to shared inbox url: '\(sharedInbox ?? "")'.")
            return
        }

        context.logger.info("Sending favourite: '\(statusFavourite.stringId() ?? "")' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
        let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
        
        do {
            try await activityPubClient.like(statusFavouriteId: statusFavourite.stringId() ?? "",
                                             activityPubStatusId: statusFavourite.status.activityPubId,
                                             activityPubProfile: statusFavourite.user.activityPubProfile,
                                             on: sharedInboxUrl)
        } catch {
            await context.logger.store("Sending favourite to shared inbox error. Shared inbox url: \(sharedInboxUrl).", error, on: context.application)
        }
    }
    
    private func createUnfavouriteOnRemoteServer(statusFavouriteId: String,
                                                 user: User,
                                                 status: Status,
                                                 on context: ExecutionContext) async throws {
        guard let privateKey = try await User.query(on: context.db).filter(\.$id == user.requireID()).first()?.privateKey else {
            context.logger.warning("Unfavourite: '\(statusFavouriteId)' cannot be send to shared inbox. Missing private key for user '\(user.stringId() ?? "")'.")
            return
        }
        
        let sharedInbox = status.user.sharedInbox
        
        guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
            context.logger.warning("Unfavourite: '\(statusFavouriteId)' cannot be send to shared inbox url: '\(sharedInbox ?? "")'.")
            return
        }

        context.logger.info("Sending unfavourite: '\(statusFavouriteId)' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
        let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
        
        do {
            try await activityPubClient.unlike(statusFavouriteId: statusFavouriteId,
                                               activityPubStatusId: status.activityPubId,
                                               activityPubProfile: user.activityPubProfile,
                                               on: sharedInboxUrl)
        } catch {
            await context.logger.store( "Sending unfavourite to shared inbox error. Shared inbox url: \(sharedInboxUrl).", error, on: context.application)
        }
    }
    
    private func createOnRemoteTimeline(status: Status, followersOf userId: Int64, on context: ExecutionContext) async throws {
        guard let privateKey = try await User.query(on: context.application.db).filter(\.$id == status.user.requireID()).first()?.privateKey else {
            context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing private key for user '\(status.user.stringId() ?? "")'.")
            return
        }
        
        var replyToStatus: Status? = nil
        if let replyToStatusId = status.$replyToStatus.id {
            replyToStatus = try await self.get(id: replyToStatusId, on: context.application.db)
        }
        
        let noteDto = try self.note(basedOn: status, replyToStatus: replyToStatus, on: context)
        
        let follows = try await Follow.query(on: context.application.db)
            .filter(\.$target.$id == userId)
            .filter(\.$approved == true)
            .join(User.self, on: \Follow.$source.$id == \User.$id)
            .filter(User.self, \.$isLocal == false)
            .field(User.self, \.$sharedInbox)
            .unique()
            .all()
        
        let sharedInboxes = try follows.map({ try $0.joined(User.self).sharedInbox })
        for (index, sharedInbox) in sharedInboxes.enumerated() {
            guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
                context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be send to shared inbox url: '\(sharedInbox ?? "")'.")
                continue
            }

            context.logger.info("[\(index + 1)/\(sharedInboxes.count)] Sending status: '\(status.stringId() ?? "")' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
            
            do {
                try await activityPubClient.create(note: noteDto, activityPubProfile: noteDto.attributedTo, on: sharedInboxUrl)
            } catch {
                await context.logger.store("Sending status to shared inbox error. Shared inbox url: \(sharedInboxUrl).", error, on: context.application)
            }
        }
    }
    
    private func createOnRemoteTimeline(status: Status, sharedInbox: String?, on context: ExecutionContext) async throws {
        guard let privateKey = try await User.query(on: context.application.db).filter(\.$id == status.user.requireID()).first()?.privateKey else {
            context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing private key for user '\(status.user.stringId() ?? "")'.")
            return
        }
        
        var replyToStatus: Status? = nil
        if let replyToStatusId = status.$replyToStatus.id {
            replyToStatus = try await self.get(id: replyToStatusId, on: context.application.db)
        }
        
        let noteDto = try self.note(basedOn: status, replyToStatus: replyToStatus, on: context)

        guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
            context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be send to shared inbox url: '\(sharedInbox ?? "")'.")
            return
        }

        context.logger.info("Sending status: '\(status.stringId() ?? "")' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
        let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
        
        do {
            try await activityPubClient.create(note: noteDto, activityPubProfile: noteDto.attributedTo, on: sharedInboxUrl)
        } catch {
            await context.logger.store("Sending status to shared inbox error. Shared inbox url: \(sharedInboxUrl).", error, on: context.application)
        }
    }
    
    private func createAnnoucmentsOnRemoteTimeline(status: Status, followersOf userId: Int64, on context: ExecutionContext) async throws {
        guard let privateKey = try await User.query(on: context.db).filter(\.$id == status.user.requireID()).first()?.privateKey else {
            context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be announce to shared inbox. Missing private key for user '\(status.user.stringId() ?? "")'.")
            return
        }
        
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
        
        let follows = try await Follow.query(on: context.db)
            .filter(\.$target.$id == userId)
            .filter(\.$approved == true)
            .join(User.self, on: \Follow.$source.$id == \User.$id)
            .filter(User.self, \.$isLocal == false)
            .field(User.self, \.$sharedInbox)
            .unique()
            .all()
        
        let sharedInboxes = try follows.map({ try $0.joined(User.self).sharedInbox })
        for (index, sharedInbox) in sharedInboxes.enumerated() {
            guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
                context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be announce to shared inbox url: '\(sharedInbox ?? "")'.")
                continue
            }

            context.logger.info("[\(index + 1)/\(sharedInboxes.count)] Announce status: '\(status.stringId() ?? "")' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
            
            do {
                try await activityPubClient.announce(activityPubStatusId: status.activityPubId,
                                                     activityPubProfile: status.user.activityPubProfile,
                                                     published: status.createdAt ?? Date(),
                                                     activityPubReblogProfile: reblogStatus.user.activityPubProfile,
                                                     activityPubReblogStatusId: reblogStatus.activityPubId,
                                                     on: sharedInboxUrl)
            } catch {
                await context.logger.store("Announcing status to shared inbox error. Shared inbox url: \(sharedInboxUrl).", error, on: context.application)
            }
        }
    }
    
    func deleteAnnoucmentsFromRemoteTimeline(activityPubUnreblog: ActivityPubUnreblogDto, on context: ExecutionContext) async throws {
        guard let privateKey = try await User.query(on: context.db).filter(\.$id == activityPubUnreblog.userId).first()?.privateKey else {
            context.logger.warning("Status: '\(activityPubUnreblog.activityPubReblogStatusId)' cannot be unannounced from shared inbox. Missing private key for user '\(activityPubUnreblog.activityPubProfile)'.")
            return
        }
                
        let follows = try await Follow.query(on: context.db)
            .filter(\.$target.$id == activityPubUnreblog.userId)
            .filter(\.$approved == true)
            .join(User.self, on: \Follow.$source.$id == \User.$id)
            .filter(User.self, \.$isLocal == false)
            .field(User.self, \.$sharedInbox)
            .unique()
            .all()
        
        let sharedInboxes = try follows.map({ try $0.joined(User.self).sharedInbox })
        for (index, sharedInbox) in sharedInboxes.enumerated() {
            guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
                context.logger.warning("Status: '\(activityPubUnreblog.activityPubReblogStatusId)' cannot be announce to shared inbox url: '\(sharedInbox ?? "")'.")
                continue
            }

            context.logger.info("[\(index + 1)/\(sharedInboxes.count)] Unannounce status: '\(activityPubUnreblog.activityPubReblogStatusId)' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
            
            do {
                try await activityPubClient.unannounce(activityPubStatusId: activityPubUnreblog.activityPubStatusId,
                                                       activityPubProfile: activityPubUnreblog.activityPubProfile,
                                                       published: activityPubUnreblog.published,
                                                       activityPubReblogProfile: activityPubUnreblog.activityPubReblogProfile,
                                                       activityPubReblogStatusId: activityPubUnreblog.activityPubReblogStatusId,
                                                       on: sharedInboxUrl)
            } catch {
                await context.logger.store("Unannouncing status to shared inbox error. Shared inbox url: \(sharedInboxUrl).", error, on: context.application)
            }
        }
    }
    
    func convertToDtos(statuses: [Status], on context: ExecutionContext) async -> [StatusDto] {
        let baseStoragePath = context.services.storageService.getBaseStoragePath(on: context)
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
                let reblogAttachmentDtos = reblogStatus.attachments.map({ AttachmentDto(from: $0, baseStoragePath: baseStoragePath) })
                reblogDto = StatusDto(from: reblogStatus,
                                      baseAddress: baseAddress,
                                      baseStoragePath: baseStoragePath,
                                      attachments: reblogAttachmentDtos,
                                      reblog: nil,
                                      isFavourited: favouritedStatuses?.contains(where: { $0 == reblogStatus.id }) ?? false,
                                      isReblogged: rebloggedStatuses?.contains(where: { $0 == reblogStatus.id }) ?? false,
                                      isBookmarked: bookmarkedStatuses?.contains(where: { $0 == reblogStatus.id }) ?? false,
                                      isFeatured: featuredStatuses?.contains(where: { $0 == reblogStatus.id }) ?? false)
            }
            
            let attachmentDtos = status.attachments.map({ AttachmentDto(from: $0, baseStoragePath: baseStoragePath) })
            return StatusDto(from: status,
                             baseAddress: baseAddress,
                             baseStoragePath: baseStoragePath,
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
        let baseStoragePath = context.services.storageService.getBaseStoragePath(on: context)
        let baseAddress = context.settings.cached?.baseAddress ?? ""

        let attachmentDtos = attachments.map({ AttachmentDto(from: $0, baseStoragePath: baseStoragePath) })
        
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
                         baseAddress: baseAddress,
                         baseStoragePath: baseStoragePath,
                         attachments: attachmentDtos,
                         reblog: reblogDto,
                         isFavourited: isFavourited ?? false,
                         isReblogged: isReblogged ?? false,
                         isBookmarked: isBookmarked ?? false,
                         isFeatured: isFeatured ?? false)
    }
    
    func can(view status: Status, authorizationPayloadId: Int64, on context: ExecutionContext) async throws -> Bool {
        // When user is owner of the status.
        if status.user.id == authorizationPayloadId {
            return true
        }

        // These statuses can see all of the people over the internet.
        if status.visibility == .public || status.visibility == .followers {
            return true
        }
        
        // For mentioned visibility we have to check if user has been connected with status.
        if try await UserStatus.query(on: context.db)
            .filter(\.$status.$id == status.requireID())
            .filter(\.$user.$id == authorizationPayloadId)
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
        
        // We have to delete notification markers which points to notification to delete.
        // Maybe in the future we can figure out something more clever.
        let notificationIds = try notifications.map { try $0.requireID() }
        let notificationMarkers = try await NotificationMarker.query(on: database)
            .filter(\.$notification.$id ~~ notificationIds)
            .all()
        
        try await database.transaction { transaction in
            for attachment in status.attachments {
                try await attachment.exif?.delete(on: transaction)
                try await attachment.delete(on: transaction)
                try await attachment.originalFile.delete(on: transaction)
                try await attachment.smallFile.delete(on: transaction)
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
            try await status.delete(on: transaction)
        }
    }
    
    func deleteFromRemote(statusActivityPubId: String, userId: Int64, on context: ExecutionContext) async throws {
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
        
        let sharedInboxes = users.map({  $0.sharedInbox })
        for (index, sharedInbox) in sharedInboxes.enumerated() {
            guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
                context.logger.warning("Status delete: '\(statusActivityPubId)' cannot be send to shared inbox url: '\(sharedInbox ?? "")'.")
                continue
            }

            context.logger.info("[\(index + 1)/\(sharedInboxes.count)] Sending status delete: '\(statusActivityPubId)' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
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
        return try await Status.query(on: database)
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
    }
    
    func unlist(statusId: Int64, on database: Database) async throws {
        try await UserStatus.query(on: database)
            .filter(\.$status.$id == statusId)
            .delete()
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
    
    private func getCategory(basedOn hashtags: [NoteHashtagDto], on database: Database) async throws -> Category? {
        let hashtagString = hashtags.map { $0.name }
        return try await getCategory(basedOn: hashtagString, on: database)
    }
    
    private func getCategory(basedOn hashtags: [String], on database: Database) async throws -> Category? {
        guard hashtags.count > 0 else {
            return nil
        }
        
        let hashtagsNormalized = hashtags.map { $0.uppercased() }
        let categoryHashtag = try await CategoryHashtag.query(on: database)
            .filter(\.$hashtagNormalized ~~ hashtagsNormalized)
            .with(\.$category)
            .first()
        
        return categoryHashtag?.category
    }
    
    private func saveAttachment(attachment: MediaAttachmentDto, userId: Int64, on context: ExecutionContext) async throws -> Attachment? {
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
        
        // Save resized image in temp folder.
        context.logger.info("Saving resized image '\(fileName)' in temporary folder.")
        let tmpSmallFileUrl = try temporaryFileService.temporaryPath(based: fileName, on: context)
        resized.write(to: tmpSmallFileUrl, quality: Constants.imageQuality)
        
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
                                              locationId: locationId)
        
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
                               film: exifDto.film) {
                try await attachmentEntity.$exif.create(exif, on: database)
            }
            
            context.logger.info("Attachment '\(attachment.url)' saved in database.")
        }
        
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
        
        return savedOriginalHdrFileName
    }
}
