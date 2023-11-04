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
    func get(on database: Database, activityPubUrl: String) async throws -> Status?
    func get(on database: Database, id: Int64) async throws -> Status?
    func count(on database: Database, for userId: Int64) async throws -> Int
    func note(basedOn status: Status, on application: Application) throws -> NoteDto
    func updateStatusCount(on database: Database, for userId: Int64) async throws
    func send(status statusId: Int64, on context: QueueContext) async throws
    func send(reblog statusId: Int64, on context: QueueContext) async throws
    func create(basedOn noteDto: NoteDto, userId: Int64, on context: QueueContext) async throws -> Status
    func createOnLocalTimeline(statusId: Int64, followersOf userId: Int64, on context: QueueContext) async throws
    func convertToDtos(on request: Request, status: Status, attachments: [Attachment]) async -> StatusDto
    func can(view status: Status, authorizationPayloadId: Int64, on request: Request) async throws -> Bool
    func getOrginalStatus(id: Int64, on database: Database) async throws -> Status?
    func replies(for statusId: Int64, on database: Database) async throws -> [Status]
    func updateReblogsCount(for statusId: Int64, on database: Database) async throws
}

final class StatusesService: StatusesServiceType {
    func get(on database: Database, activityPubUrl: String) async throws -> Status? {
        return try await Status.query(on: database).filter(\.$activityPubUrl == activityPubUrl).first()
    }
    
    func get(on database: Database, id: Int64) async throws -> Status? {
        return try await Status.query(on: database)
            .filter(\.$id == id)
            .with(\.$user)
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
    }
    
    func count(on database: Database, for userId: Int64) async throws -> Int {
        return try await Status.query(on: database).filter(\.$user.$id == userId).count()
    }
    
    func note(basedOn status: Status, on application: Application) throws -> NoteDto {
        let baseStoragePath = application.services.storageService.getBaseStoragePath(on: application)
        
        let appplicationSettings = application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""

        let noteDto = try NoteDto(id: "\(status.user.activityPubProfile)/statuses/\(status.requireID())",
                                  summary: nil,
                                  inReplyTo: nil,
                                  published: status.createdAt?.toISO8601String(),
                                  url: "\(baseAddress)/@\(status.user.userName)/\(status.requireID())",
                                  attributedTo: status.user.activityPubProfile,
                                  to: .multiple([
                                    ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")
                                  ]),
                                  cc: .multiple([
                                    ActorDto(id: "\(status.user.activityPubProfile)/followers")
                                  ]),
                                  contentWarning: status.contentWarning,
                                  atomUri: nil,
                                  inReplyToAtomUri: nil,
                                  conversation: nil,
                                  content: status.note?.html(baseAddress: baseAddress),
                                  attachment: status.attachments.map({ MediaAttachmentDto(from: $0, baseStoragePath: baseStoragePath) }),
                                  tag: status.hashtags.map({ NoteHashtagDto(from: $0, baseAddress: baseAddress) }))
        
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
        
        switch status.visibility {
        case .public, .followers:
            // Create status on owner tineline.
            let ownerUserStatus = try UserStatus(userId: status.user.requireID(), statusId: statusId)
            try await ownerUserStatus.create(on: context.application.db)
            
            // Create statuses on local followers timeline.
            try await self.createOnLocalTimeline(statusId: status.requireID(), followersOf: status.user.requireID(), on: context)
            
            // Create statuses on remote followers timeline.
            try await self.createOnRemoteTimeline(status: status, followersOf: status.user.requireID(), on: context)
        case .mentioned:
            let userIds = try await self.getMentionedUsers(for: status, on: context)
            for userId in userIds {
                let userStatus = UserStatus(userId: userId, statusId: statusId)
                try await userStatus.create(on: context.application.db)
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
            try await self.createOnLocalTimeline(statusId: status.requireID(), followersOf: status.user.requireID(), on: context)
            
            // Create reblogged statuses on remote followers timeline.
            try await self.createAnnoucmentsOnRemoteTimeline(status: status, followersOf: status.user.requireID(), on: context)
        case .mentioned:
            break
        }
    }
    
    func create(basedOn noteDto: NoteDto, userId: Int64, on context: QueueContext) async throws -> Status {
        guard let attachments = noteDto.attachment else {
            throw StatusError.attachmentsAreRequired
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
        
        let status = Status(isLocal: false,
                            userId: userId,
                            note: noteDto.content ?? "",
                            activityPubId: noteDto.id,
                            activityPubUrl: noteDto.url,
                            application: Constants.applicationName,
                            visibility: .public,
                            sensitive: noteDto.sensitive,
                            contentWarning: noteDto.contentWarning)

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
            let hashtags = status.note?.getHashtags() ?? []
            for hashtag in hashtags {
                let statusHashtag = try StatusHashtag(statusId: status.requireID(), hashtag: hashtag)
                try await statusHashtag.save(on: database)
            }
            
            // Create mentions based on note.
            let userNames = status.note?.getUserNames() ?? []
            for userName in userNames {
                let statusMention = try StatusMention(statusId: status.requireID(), userName: userName)
                try await statusMention.save(on: database)
            }
            
            context.logger.info("Status '\(noteDto.url)' saved in database.")
        }
        
        return status
    }
    
    func createOnLocalTimeline(statusId: Int64, followersOf userId: Int64, on context: QueueContext) async throws {
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
                                let userStatus = UserStatus(userId: success.$source.id, statusId: statusId)
                                try await userStatus.create(on: context.application.db)
                            case .failure(let failure):
                                context.logger.error("Status \(statusId) cannot be added to the user. Error: \(failure.localizedDescription).")
                            }
                        } catch {
                            context.logger.error("Status \(statusId) cannot be added to the user. Error: \(error.localizedDescription).")
                        }
                    }
                }
            }
    }
    
    private func createOnRemoteTimeline(status: Status, followersOf userId: Int64, on context: QueueContext) async throws {
        guard let privateKey = try await User.query(on: context.application.db).filter(\.$id == status.user.requireID()).first()?.privateKey else {
            context.logger.warning("Status: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing private key for user '\(status.user.stringId() ?? "")'.")
            return
        }
        
        let noteDto = try self.note(basedOn: status, on: context.application)
        
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
    
    func convertToDtos(on request: Request, status: Status, attachments: [Attachment]) async -> StatusDto {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        let attachmentDtos = attachments.map({ AttachmentDto(from: $0, baseStoragePath: baseStoragePath) })
        
        let isFavourited = false
        let isReblogged = try? await self.statusIsReblogged(on: request, statusId: status.requireID())
        let isBookmarked = false
        
        var reblogDto: StatusDto?
        if let reblogId = status.$reblog.id,
           let reblog = try? await self.get(on: request.db, id: reblogId) {
            reblogDto = await self.convertToDtos(on: request, status: reblog, attachments: reblog.attachments)
        }
        
        return StatusDto(from: status,
                         baseAddress: baseAddress,
                         baseStoragePath: baseStoragePath,
                         attachments: attachmentDtos,
                         reblog: reblogDto,
                         isFavourited: isFavourited,
                         isReblogged: isReblogged ?? false,
                         isBookmarked: isBookmarked)
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
    
    func replies(for statusId: Int64, on database: Database) async throws -> [Status] {
        var replies: [Status] = []
        try await self.download(replies: &replies, for: statusId, on: database)

        return replies
    }
    
    private func download(replies statuses: inout [Status], for statusId: Int64, on database: Database) async throws {
        let repliesFor = try await Status.query(on: database)
            .filter(\.$replyToStatus.$id == statusId)
            .all()
        
        statuses.append(contentsOf: repliesFor)
        for reply in repliesFor {
            try await self.download(replies: &statuses, for: reply.requireID(), on: database)
        }
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
}
