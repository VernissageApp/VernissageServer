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
    func updateStatusCount(on database: Database, for userId: Int64) async throws
    func send(status statusId: Int64, on context: QueueContext) async throws
    func create(basedOn baseObjectDto: BaseObjectDto, userId: Int64, on context: QueueContext) async throws -> Status
    func createOnTimeline(statusId: Int64, followersOf userId: Int64, on context: QueueContext) async throws
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
            .first()
    }
    
    func count(on database: Database, for userId: Int64) async throws -> Int {
        return try await Status.query(on: database).filter(\.$user.$id == userId).count()
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
        guard let status = try await Status.query(on: context.application.db)
            .filter(\.$id == statusId)
            .with(\.$user)
            .with(\.$mentions)
            .first() else {
            throw EntityNotFoundError.statusNotFound
        }
        
        switch status.visibility {
        case .public, .followers:
            // Create status on owner tineline.
            let ownerUserStatus = try UserStatus(userId: status.user.requireID(), statusId: statusId)
            try await ownerUserStatus.create(on: context.application.db)
            
            // Create statuses on followers timeline.
            try await self.createOnTimeline(statusId: status.requireID(), followersOf: status.user.requireID(), on: context)
        case .mentioned:
            let userIds = try await self.getMentionedUsers(for: status, on: context)
            for userId in userIds {
                let userStatus = UserStatus(userId: userId, statusId: statusId)
                try await userStatus.create(on: context.application.db)
            }
        }
    }
    
    func create(basedOn baseObjectDto: BaseObjectDto, userId: Int64, on context: QueueContext) async throws -> Status {
        guard let attachments = baseObjectDto.attachment else {
            throw StatusError.attachmentsAreRequired
        }
        
        var savedAttachments: [Attachment] = []
        
        for attachment in attachments {
            if attachment.mediaType.starts(with: "image/") {
                
                let temporaryFileService = context.application.services.temporaryFileService
                let storageService = context.application.services.storageService
                
                // Save image to temp folder.
                let tmpOriginalFileUrl = try await temporaryFileService.save(url: attachment.url, on: context)
                
                // Create image in the memory.
                guard let image = Image(url: tmpOriginalFileUrl) else {
                    throw AttachmentError.createResizedImageFailed
                }
                
                // Resize image.
                guard let resized = image.resizedTo(width: 800) else {
                    throw AttachmentError.resizedImageFailed
                }
                
                // Get fileName from URL.
                let fileName = attachment.url.fileName()
                
                // Save resized image in temp folder.
                let tmpSmallFileUrl = try temporaryFileService.temporaryPath(on: context.application, based: fileName)
                resized.write(to: tmpSmallFileUrl)
                
                // Save original image.
                guard let savedOriginalFileName = try await storageService.save(fileName: fileName, url: tmpOriginalFileUrl, on: context) else {
                    throw AttachmentError.savedFailed
                }
                
                // Save small image.
                guard let savedSmallFileName = try await storageService.save(fileName: fileName, url: tmpSmallFileUrl, on: context) else {
                    throw AttachmentError.savedFailed
                }
                
                // Prepare obejct to save in database.
                let originalFileInfo = FileInfo(fileName: savedOriginalFileName, width: image.size.width, height: image.size.height)
                let smallFileInfo = FileInfo(fileName: savedSmallFileName, width: resized.size.width, height: resized.size.height)
                let attachmentEntity = try Attachment(userId: userId,
                                                      originalFileId: originalFileInfo.requireID(),
                                                      smallFileId: smallFileInfo.requireID(),
                                                      description: attachment.name,
                                                      blurhash: attachment.blurhash)
                
                // Operation in database should be performed in one transaction.
                try await context.application.db.transaction { database in
                    try await originalFileInfo.save(on: database)
                    try await smallFileInfo.save(on: database)
                    try await attachmentEntity.save(on: database)
                }
                
                savedAttachments.append(attachmentEntity)
            }
        }
        
        let status = Status(isLocal: false,
                            userId: userId,
                            note: baseObjectDto.content ?? "",
                            activityPubId: baseObjectDto.id,
                            activityPubUrl: baseObjectDto.url,
                            visibility: .public,
                            sensitive: baseObjectDto.sensitive ?? false,
                            contentWarning: baseObjectDto.contentWarning)

        let attachmentsFromDatabase = savedAttachments
        
        try await context.application.db.transaction { database in
            // Save status in database.
            try await status.save(on: context.application.db)
            
            // Connect attachments with new status.
            for attachment in attachmentsFromDatabase {
                attachment.$status.id = status.id
                try await attachment.save(on: database)
            }
            
            // Create hashtags based on note.
            let hashtags = status.note.getHashtags()
            for hashtag in hashtags {
                let statusHashtag = try StatusHashtag(statusId: status.requireID(), hashtag: hashtag)
                try await statusHashtag.save(on: database)
            }
            
            // Create mentions based on note.
            let userNames = status.note.getUserNames()
            for userName in userNames {
                let statusMention = try StatusMention(statusId: status.requireID(), userName: userName)
                try await statusMention.save(on: database)
            }
        }
        
        return status
    }
    
    func createOnTimeline(statusId: Int64, followersOf userId: Int64, on context: QueueContext) async throws {
        try await Follow.query(on: context.application.db)
            .filter(\.$target.$id == userId)
            .filter(\.$approved == true)
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
