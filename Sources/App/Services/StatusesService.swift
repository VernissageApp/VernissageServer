//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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

protocol StatusesServiceType {
    func get(on database: Database, activityPubId: String) async throws -> Status?
    func get(on database: Database, id: Int64) async throws -> Status?
    func get(on database: Database, ids: [Int64]) async throws -> [Status]
    func count(on database: Database, for userId: Int64) async throws -> Int
    func count(on database: Database, onlyComments: Bool) async throws -> Int
    func note(basedOn status: Status, replyToStatus: Status?, on application: Application) throws -> NoteDto
    func updateStatusCount(on database: Database, for userId: Int64) async throws
    func send(status statusId: Int64, on context: QueueContext) async throws
    func send(reblog statusId: Int64, on context: QueueContext) async throws
    func send(unreblog activityPubUnreblog: ActivityPubUnreblogDto, on context: QueueContext) async throws
    func create(basedOn noteDto: NoteDto, userId: Int64, on context: QueueContext) async throws -> Status
    func createOnLocalTimeline(followersOf userId: Int64, status: Status, on context: QueueContext) async throws
    func convertToDto(on request: Request, status: Status, attachments: [Attachment]) async -> StatusDto
    func convertToDtos(on request: Request, statuses: [Status]) async -> [StatusDto]
    func can(view status: Status, authorizationPayloadId: Int64, on request: Request) async throws -> Bool
    func getOrginalStatus(id: Int64, on database: Database) async throws -> Status?
    func getReblogStatus(id: Int64, userId: Int64, on database: Database) async throws -> Status?
    func delete(owner userId: Int64, on database: Database) async throws
    func delete(id statusId: Int64, on database: Database) async throws
    func deleteFromRemote(statusActivityPubId: String, userId: Int64, on context: QueueContext) async throws
    func updateReblogsCount(for statusId: Int64, on database: Database) async throws
    func updateFavouritesCount(for statusId: Int64, on database: Database) async throws
    func statuses(for userId: Int64, linkableParams: LinkableParams, on request: Request) async throws -> LinkableResult<Status>
    func statuses(linkableParams: LinkableParams, on request: Request) async throws -> LinkableResult<Status>
    func ancestors(for statusId: Int64, on database: Database) async throws -> [Status]
    func descendants(for statusId: Int64, on database: Database) async throws -> [Status]
    func reblogged(on request: Request, statusId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<User>
    func favourited(on request: Request, statusId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<User>
}

final class StatusesService: StatusesServiceType {
    func get(on database: Database, activityPubId: String) async throws -> Status? {
        return try await Status.query(on: database)
            .with(\.$user)
            .group(.or) { group in
                group
                    .filter(\.$activityPubId == activityPubId)
                    .filter(\.$activityPubUrl == activityPubId)
            }
            .first()
    }
    
    func get(on database: Database, id: Int64) async throws -> Status? {
        return try await Status.query(on: database)
            .filter(\.$id == id)
            .with(\.$user)
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
            .with(\.$mentions)
            .with(\.$category)
            .first()
    }
    
    func get(on database: Database, ids: [Int64]) async throws -> [Status] {
        return try await Status.query(on: database)
            .filter(\.$id ~~ ids)
            .with(\.$user)
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
            .with(\.$mentions)
            .with(\.$category)
            .all()
    }
    
    func count(on database: Database, for userId: Int64) async throws -> Int {
        return try await Status.query(on: database).filter(\.$user.$id == userId).count()
    }
    
    func count(on database: Database, onlyComments: Bool) async throws -> Int {
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
    
    func note(basedOn status: Status, replyToStatus: Status?, on application: Application) throws -> NoteDto {
        let baseStoragePath = application.services.storageService.getBaseStoragePath(on: application)
        
        let appplicationSettings = application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""

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
                              content: status.note?.html(baseAddress: baseAddress),
                              attachment: status.attachments.map({ MediaAttachmentDto(from: $0, baseStoragePath: baseStoragePath) }),
                              tag: .multiple(
                                status.hashtags.map({NoteHashtagDto(from: $0, baseAddress: baseAddress)})
                              ))
        
        return noteDto
    }
    
    func updateStatusCount(on database: Database, for userId: Int64) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }

        try await sql.raw("""
            UPDATE \(ident: User.schema)
            SET \(ident: "statusesCount") = (SELECT count(1) FROM \(ident: Status.schema) WHERE \(ident: "userId") = \(bind: userId))
            WHERE \(ident: "id") = \(bind: userId)
        """).run()
    }
    
    func send(status statusId: Int64, on context: QueueContext) async throws {
        guard let status = try await self.get(on: context.application.db, id: statusId) else {
            throw Abort(.notFound)
        }
        
        // When status is response for other status (comment) we are sending the notification to parent status owner.
        if let replyToStatusId = status.$replyToStatus.id {
            try await self.notifyOwnerAboutComment(statusId: replyToStatusId, by: status.user.requireID(), on: context)
        }
        
        let statusIsComment = status.$replyToStatus.id != nil
        
        switch status.visibility {
        case .public, .followers:
            if statusIsComment == false {
                // Create status on owner tineline.
                let ownerUserStatus = try UserStatus(type: .owner, userId: status.user.requireID(), statusId: statusId)
                try await ownerUserStatus.create(on: context.application.db)
                
                // Create statuses on local followers timeline.
                try await self.createOnLocalTimeline(followersOf: status.user.requireID(), status: status, on: context)
                
                // Create mention notifications.
                try await self.createMentionNotifications(status: status, on: context)
            }
            
            // Create statuses on remote followers timeline.
            try await self.createOnRemoteTimeline(status: status, followersOf: status.user.requireID(), on: context)
        case .mentioned:
            if statusIsComment == false {
                let userIds = try await self.getMentionedUsers(for: status, on: context)
                for userId in userIds {
                    let userStatus = UserStatus(type: .mention, userId: userId, statusId: statusId)
                    try await userStatus.create(on: context.application.db)
                }
            }
        }
    }
    
    func send(reblog statusId: Int64, on context: QueueContext) async throws {
        guard let status = try await self.get(on: context.application.db, id: statusId) else {
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
    
    func send(unreblog activityPubUnreblog: ActivityPubUnreblogDto, on context: QueueContext) async throws {
        guard let orginalStatus = try await self.get(on: context.application.db, id: activityPubUnreblog.orginalStatusId) else {
            throw Abort(.notFound)
        }
        
        switch orginalStatus.visibility {
        case .public, .followers:
            try await self.deleteAnnoucmentsFromRemoteTimeline(activityPubUnreblog: activityPubUnreblog, on: context)
        case .mentioned:
            break
        }
    }
    
    func create(basedOn noteDto: NoteDto, userId: Int64, on context: QueueContext) async throws -> Status {
        guard let attachments = noteDto.attachment else {
            throw StatusError.attachmentsAreRequired
        }
        
        var replyToStatus: Status? = nil
        if let replyToActivityPubId = noteDto.inReplyTo {
            context.logger.info("Downloading commented status '\(replyToActivityPubId)' from local database.")
            replyToStatus = try await self.get(on: context.application.db, activityPubId: replyToActivityPubId)

            if replyToStatus == nil {
                context.logger.info("Status '\(replyToActivityPubId)' cannot found in local database. Adding comment has been terminated.")
                throw StatusError.cannotAddCommentWithoutCommentedStatus
            }
        }
        
        var savedAttachments: [Attachment] = []
        
        for attachment in attachments {
            if attachment.mediaType.starts(with: "image/") {
                
                let temporaryFileService = context.application.services.temporaryFileService
                let storageService = context.application.services.storageService
                
                // Save image to temp folder.
                context.logger.info("Saving attachment '\(attachment.url)' to temporary folder.")
                let tmpOriginalFileUrl = try await temporaryFileService.save(url: attachment.url, on: context)
                
                // Create image in the memory.
                context.logger.info("Opening image '\(attachment.url)' in memory.")
                guard let image = Image(url: tmpOriginalFileUrl) else {
                    throw AttachmentError.createResizedImageFailed
                }
                
                // Resize image.
                context.logger.info("Resizing image '\(attachment.url)'.")
                guard let resized = image.resizedTo(width: 800) else {
                    throw AttachmentError.resizedImageFailed
                }
                
                // Get fileName from URL.
                let fileName = attachment.url.fileName()
                
                // Save resized image in temp folder.
                context.logger.info("Saving resized image '\(fileName)' in temporary folder.")
                let tmpSmallFileUrl = try temporaryFileService.temporaryPath(on: context.application, based: fileName)
                resized.write(to: tmpSmallFileUrl)
                
                // Save original image.
                context.logger.info("Saving orginal image '\(tmpOriginalFileUrl)' in storage provider.")
                guard let savedOriginalFileName = try await storageService.save(fileName: fileName, url: tmpOriginalFileUrl, on: context) else {
                    throw AttachmentError.savedFailed
                }
                
                // Save small image.
                context.logger.info("Saving resized image '\(tmpSmallFileUrl)' in storage provider.")
                guard let savedSmallFileName = try await storageService.save(fileName: fileName, url: tmpSmallFileUrl, on: context) else {
                    throw AttachmentError.savedFailed
                }
                
                // Get location id.
                var locationId: Int64? = nil
                if let geonameId = attachment.location?.geonameId {
                    locationId = try await Location.query(on: context.application.db).filter(\.$geonameId == geonameId).first()?.id
                }
                
                // Prepare obejct to save in database.
                let originalFileInfo = FileInfo(fileName: savedOriginalFileName, width: image.size.width, height: image.size.height)
                let smallFileInfo = FileInfo(fileName: savedSmallFileName, width: resized.size.width, height: resized.size.height)
                let attachmentEntity = try Attachment(userId: userId,
                                                      originalFileId: originalFileInfo.requireID(),
                                                      smallFileId: smallFileInfo.requireID(),
                                                      description: attachment.name,
                                                      blurhash: attachment.blurhash,
                                                      locationId: locationId)
                                
                // Operation in database should be performed in one transaction.
                context.logger.info("Saving attachment '\(attachment.url)' in database.")
                try await context.application.db.transaction { database in
                    try await originalFileInfo.save(on: database)
                    try await smallFileInfo.save(on: database)
                    try await attachmentEntity.save(on: database)
                    
                    if let exifDto = attachment.exif,
                       let exif = Exif(make: exifDto.make,
                                       model: exifDto.model,
                                       lens: exifDto.lens,
                                       createDate: exifDto.createDate,
                                       focalLenIn35mmFilm: exifDto.focalLenIn35mmFilm,
                                       fNumber: exifDto.fNumber,
                                       exposureTime: exifDto.exposureTime,
                                       photographicSensitivity: exifDto.photographicSensitivity) {
                        try await attachmentEntity.$exif.create(exif, on: database)
                    }
                    
                    context.logger.info("Attachment '\(attachment.url)' saved in database.")
                }
                
                savedAttachments.append(attachmentEntity)
            }
        }
        
        let userNames = noteDto.content?.getUserNames() ?? []
        let hashtags = noteDto.content?.getHashtags() ?? []
        let category = try await self.getCategory(basedOn: hashtags, on: context.application.db)
        
        let status = Status(isLocal: false,
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
                let statusHashtag = try StatusHashtag(statusId: status.requireID(), hashtag: hashtag)
                try await statusHashtag.save(on: database)
            }
            
            // Create mentions based on note.
            for userName in userNames {
                let statusMention = try StatusMention(statusId: status.requireID(), userName: userName)
                try await statusMention.save(on: database)
            }
            
            context.logger.info("Status '\(noteDto.url)' saved in database.")
        }
        
        // We can add notification to user about new comment/mention.
        if let replyToStatus,
           let statusFromDatabase = try await self.get(on: context.application.db, id: status.requireID()) {
            
            let notificationsService = context.application.services.notificationsService
            try await notificationsService.create(type: .newComment,
                                                  to: replyToStatus.user,
                                                  by: statusFromDatabase.user.requireID(),
                                                  statusId: replyToStatus.requireID(),
                                                  on: context.application.db)

            context.logger.info("Notification (mention) about new comment to user '\(replyToStatus.user.activityPubProfile)' added to database.")
        }
        
        return status
    }
    
    func createOnLocalTimeline(followersOf userId: Int64, status: Status, on context: QueueContext) async throws {
        let isReblog = status.$reblog.id != nil
        
        try await Follow.query(on: context.application.db)
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
                                
                                let userMute = try await self.getUserMute(userId: followerId, mutedUserId: userId, on: context.application.db)
                                
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
                                    let userStatus = try UserStatus(type: isReblog ? .reblog : .follow,
                                                                    userId: followerId,
                                                                    statusId: status.requireID())

                                    try await userStatus.create(on: context.application.db)
                                }
                            case .failure(let failure):
                                context.logger.error("Status \(status.stringId() ?? "") cannot be added to the user. Error: \(failure.localizedDescription).")
                            }
                        } catch {
                            context.logger.error("Status \(status.stringId() ?? "") cannot be added to the user. Error: \(error.localizedDescription).")
                        }
                    }
                }
            }
    }
    
    public func reblogged(on request: Request, statusId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<User> {
        var queryBuilder = Status.query(on: request.db)
            .with(\.$user)
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
    
    public func favourited(on request: Request, statusId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<User> {
        var queryBuilder = StatusFavourite.query(on: request.db)
            .with(\.$user)
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
    
    private func getUserMute(userId: Int64, mutedUserId: Int64, on database: Database) async throws -> UserMute {
        return try await UserMute.query(on: database)
            .filter(\.$user.$id == userId)
            .filter(\.$mutedUser.$id == mutedUserId)
            .group(.or) { group in
                group
                    .filter(\.$muteEnd == nil)
                    .filter(\.$muteEnd > Date())
            }
            .first() ?? UserMute(userId: userId, mutedUserId: mutedUserId, muteStatuses: false, muteReblogs: false, muteNotifications: false)
    }
    
    private func alreadyExistsInUserTimeline(userId: Int64, status: Status, on context: QueueContext) async -> Bool {
        guard let orginalStatusId = status.$reblog.id ?? status.id else {
            return false
        }
        
        // Check if user alredy have orginal status (picture) on timeline (as orginal picture or reblogged).
        let statuses = try? await UserStatus.query(on: context.application.db)
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
    private func notifyOwnerAboutComment(statusId: Int64, by userId: Int64, on context: QueueContext) async throws {
        guard let status = try await self.get(on: context.application.db, id: statusId) else {
            return
        }
        
        let ancestors = try await self.ancestors(for: statusId, on: context.application.db)

        let notificationsService = context.application.services.notificationsService
        try await notificationsService.create(type: .newComment,
                                              to: status.user,
                                              by: userId,
                                              statusId: ancestors.first?.requireID(),
                                              on: context.application.db)
    }
    
    private func createMentionNotifications(status: Status, on context: QueueContext) async throws {
        for mention in status.mentions {
            let user = try await User.query(on: context.application.db)
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
            let notificationsService = context.application.services.notificationsService
            try await notificationsService.create(type: .mention,
                                                  to: user,
                                                  by: status.$user.id,
                                                  statusId: status.requireID(),
                                                  on: context.application.db)
        }
    }
    
    private func createOnRemoteTimeline(status: Status, followersOf userId: Int64, on context: QueueContext) async throws {
        guard let privateKey = try await User.query(on: context.application.db).filter(\.$id == status.user.requireID()).first()?.privateKey else {
            context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing private key for user '\(status.user.stringId() ?? "")'.")
            return
        }
        
        var replyToStatus: Status? = nil
        if let replyToStatusId = status.$replyToStatus.id {
            replyToStatus = try await self.get(on: context.application.db, id: replyToStatusId)
        }
        
        let noteDto = try self.note(basedOn: status, replyToStatus: replyToStatus, on: context.application)
        
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
                context.logger.error("Sending status to shared inbox error: \(error.localizedDescription)")
            }
        }
    }
    
    private func createAnnoucmentsOnRemoteTimeline(status: Status, followersOf userId: Int64, on context: QueueContext) async throws {
        guard let privateKey = try await User.query(on: context.application.db).filter(\.$id == status.user.requireID()).first()?.privateKey else {
            context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be announce to shared inbox. Missing private key for user '\(status.user.stringId() ?? "")'.")
            return
        }
        
        guard let reblogStatusId = status.$reblog.id else {
            context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be announce to shared inbox. Missing reblogId property.")
            return
        }
        
        guard let reblogStatus = try await Status.query(on: context.application.db)
            .filter(\.$id == reblogStatusId)
            .with(\.$user)
            .first() else {
            context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be announce to shared inbox. Missing reblog status with id: '\(reblogStatusId)'.")
            return
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
                context.logger.error("Announcing status to shared inbox error: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteAnnoucmentsFromRemoteTimeline(activityPubUnreblog: ActivityPubUnreblogDto, on context: QueueContext) async throws {
        guard let privateKey = try await User.query(on: context.application.db).filter(\.$id == activityPubUnreblog.userId).first()?.privateKey else {
            context.logger.warning("Status: '\(activityPubUnreblog.activityPubReblogStatusId)' cannot be unannounced from shared inbox. Missing private key for user '\(activityPubUnreblog.activityPubProfile)'.")
            return
        }
                
        let follows = try await Follow.query(on: context.application.db)
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
                context.logger.error("Unannouncing status to shared inbox error: \(error.localizedDescription)")
            }
        }
    }
    
    func convertToDtos(on request: Request, statuses: [Status]) async -> [StatusDto] {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        let reblogIds = statuses.compactMap { $0.$reblog.id }
        let reblogStatuses = try? await self.get(on: request.db, ids: reblogIds)
        
        let allStatusIds = statuses.compactMap { $0.id } + reblogIds
        let favouritedStatuses = try? await self.statusesAreFavourited(on: request, statusIds: allStatusIds)
        let rebloggedStatuses = try? await self.statusesAreReblogged(on: request, statusIds: allStatusIds)
        let bookmarkedStatuses = try? await self.statusesAreBookmarked(on: request, statusIds: allStatusIds)
        let featuredStatuses = try? await self.statusesAreFeatured(on: request, statusIds: allStatusIds)
                
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
    
    func convertToDto(on request: Request, status: Status, attachments: [Attachment]) async -> StatusDto {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        let attachmentDtos = attachments.map({ AttachmentDto(from: $0, baseStoragePath: baseStoragePath) })
        
        let isFavourited = try? await self.statusIsFavourited(on: request, statusId: status.requireID())
        let isReblogged = try? await self.statusIsReblogged(on: request, statusId: status.requireID())
        let isBookmarked = try? await self.statusIsBookmarked(on: request, statusId: status.requireID())
        let isFeatured = try? await self.statusIsFeatured(on: request, statusId: status.requireID())
        
        var reblogDto: StatusDto?
        if let reblogId = status.$reblog.id,
           let reblog = try? await self.get(on: request.db, id: reblogId) {
            reblogDto = await self.convertToDto(on: request, status: reblog, attachments: reblog.attachments)
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
    
    func can(view status: Status, authorizationPayloadId: Int64, on request: Request) async throws -> Bool {
        // When user is owner of the status.
        if status.user.id == authorizationPayloadId {
            return true
        }

        // These statuses can see all of the people over the internet.
        if status.visibility == .public || status.visibility == .followers {
            return true
        }
        
        // For mentioned visibility we have to check if user has been connected with status.
        if try await UserStatus.query(on: request.db)
            .filter(\.$status.$id == status.requireID())
            .filter(\.$user.$id == authorizationPayloadId)
            .first() != nil {
            return true
        }
        
        return false
    }
    
    func getOrginalStatus(id: Int64, on database: Database) async throws -> Status? {
        let status = try await self.get(on: database, id: id)
        guard let status else {
            return nil
        }

        guard let reblogId = status.$reblog.id else {
            return status
        }
        
        return try await self.get(on: database, id: reblogId)
    }
    
    func getReblogStatus(id: Int64, userId: Int64, on database: Database) async throws -> Status? {
        let status = try await Status.query(on: database)
            .filter(\.$id == id)
            .filter(\.$user.$id == userId)
            .first()
        
        // We have already reblog status Id.
        if let status, status.$reblog.id != nil {
            return try await self.get(on: database, id: status.requireID())
        }
        
        // If not we have to get status which reblogs status by the user.
        let reblog = try await Status.query(on: database)
            .filter(\.$reblog.$id == id)
            .filter(\.$user.$id == userId)
            .first()
        
        guard let reblog else {
            return nil
        }
        
        return try await self.get(on: database, id: reblog.requireID())
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
    
    func delete(owner userId: Int64, on database: Database) async throws {
        let statuses = try await Status.query(on: database)
            .filter(\.$user.$id == userId)
            .field(\.$id)
            .all()
        
        for status in statuses {
            try await self.delete(id: status.requireID(), on: database)
        }
    }
    
    func delete(id statusId: Int64, on database: Database) async throws {
        let status = try await Status.query(on: database)
            .filter(\.$id == statusId)
            .with(\.$attachments) { attachment in
                attachment.with(\.$exif)
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
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
        
        // We have to delete all notifications which mention that status.
        let notifications = try await Notification.query(on: database)
            .filter(\.$status.$id == statusId)
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
            try await notifications.delete(on: transaction)
            
            try await status.hashtags.delete(on: transaction)
            try await status.mentions.delete(on: transaction)
            try await status.delete(on: transaction)
        }
    }
    
    func deleteFromRemote(statusActivityPubId: String, userId: Int64, on context: QueueContext) async throws {
        guard let user = try await User.query(on: context.application.db)
            .filter(\.$id == userId)
            .first() else {
            context.logger.warning("User: '\(userId)' cannot exists in database.")
            return
        }

        guard let privateKey = user.privateKey else {
            context.logger.warning("Status: '\(statusActivityPubId)' cannot be send to shared inbox (delete). Missing private key.")
            return
        }
        
        let users = try await User.query(on: context.application.db)
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
                context.logger.error("Sending status delete to shared inbox error: \(error.localizedDescription)")
            }
        }
    }
    
    func statuses(for userId: Int64, linkableParams: LinkableParams, on request: Request) async throws -> LinkableResult<Status> {
        var query = Status.query(on: request.db)
            .group(.or) { group in
                group
                    .filter(\.$visibility ~~ [.public])
                    .filter(\.$user.$id == userId)
            }
            .sort(\.$createdAt, .descending)
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
    
    func statuses(linkableParams: LinkableParams, on request: Request) async throws -> LinkableResult<Status> {
        var query = Status.query(on: request.db)
            .filter(\.$visibility ~~ [.public])
            .sort(\.$createdAt, .descending)
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
            if let ancestor = try await self.get(on: database, id: currentStatudId) {
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
        
    private func statusIsReblogged(on request: Request, statusId: Int64) async throws -> Bool {
        guard let authorizationPayloadId = request.userId else {
            return false
        }
        
        let amountOfStatuses = try await Status.query(on: request.db)
            .filter(\.$reblog.$id == statusId)
            .filter(\.$user.$id == authorizationPayloadId)
            .count()
        
        return amountOfStatuses > 0
    }
    
    private func statusesAreReblogged(on request: Request, statusIds: [Int64]) async throws -> [Int64] {
        guard let authorizationPayloadId = request.userId else {
            return []
        }
        
        let rebloggedStatuses = try await Status.query(on: request.db)
            .filter(\.$reblog.$id ~~ statusIds)
            .filter(\.$user.$id == authorizationPayloadId)
            .field(\.$reblog.$id)
            .all()
        
        return rebloggedStatuses.compactMap({ $0.$reblog.id })
    }
    
    private func statusIsFavourited(on request: Request, statusId: Int64) async throws -> Bool {
        guard let authorizationPayloadId = request.userId else {
            return false
        }
        
        let amountOfFavourites = try await StatusFavourite.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .count()
        
        return amountOfFavourites > 0
    }
    
    private func statusesAreFavourited(on request: Request, statusIds: [Int64]) async throws -> [Int64] {
        guard let authorizationPayloadId = request.userId else {
            return []
        }
        
        let favouritedStatuses = try await StatusFavourite.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id ~~ statusIds)
            .field(\.$status.$id)
            .all()
        
        return favouritedStatuses.map({ $0.$status.id })
    }
    
    private func statusIsBookmarked(on request: Request, statusId: Int64) async throws -> Bool {
        guard let authorizationPayloadId = request.userId else {
            return false
        }
        
        let amountOfBookmarks = try await StatusBookmark.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .count()
        
        return amountOfBookmarks > 0
    }
    
    private func statusesAreBookmarked(on request: Request, statusIds: [Int64]) async throws -> [Int64] {
        guard let authorizationPayloadId = request.userId else {
            return []
        }
        
        let bookmarkedStatuses = try await StatusBookmark.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id ~~ statusIds)
            .field(\.$status.$id)
            .all()
        
        return bookmarkedStatuses.map({ $0.$status.id })
    }
    
    private func statusIsFeatured(on request: Request, statusId: Int64) async throws -> Bool {
        guard let authorizationPayloadId = request.userId else {
            return false
        }
        
        let amount = try await FeaturedStatus.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .count()
        
        return amount > 0
    }
    
    private func statusesAreFeatured(on request: Request, statusIds: [Int64]) async throws -> [Int64] {
        guard let authorizationPayloadId = request.userId else {
            return []
        }
        
        let featuredStatuses = try await FeaturedStatus.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id ~~ statusIds)
            .field(\.$status.$id)
            .all()
        
        return featuredStatuses.map({ $0.$status.id })
    }
    
    private func getMentionedUsers(for status: Status, on context: QueueContext) async throws -> [Int64] {
        var userIds: [Int64] = []
        
        for mention in status.mentions {
            let user = try await User.query(on: context.application.db)
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
}
