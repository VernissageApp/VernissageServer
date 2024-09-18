//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func getStatus(id: Int64) async throws -> Status? {
        return try await Status.query(on: self.db).filter(\.$id == id).first()
    }
    
    func getStatus(reblogId: Int64) async throws -> Status? {
        return try await Status.query(on: self.db).filter(\.$reblog.$id == reblogId).first()
    }

    func createStatus(
        user: User,
        note: String,
        attachmentIds: [String],
        visibility: StatusVisibilityDto = .public,
        replyToStatusId: String? = nil,
        categoryId: String? = nil
    ) async throws -> Status {
        let statusRequestDto = StatusRequestDto(note: note,
                                                visibility: visibility,
                                                sensitive: false,
                                                contentWarning: nil,
                                                commentsDisabled: false,
                                                categoryId: categoryId,
                                                replyToStatusId: replyToStatusId,
                                                attachmentIds: attachmentIds)

        let createdStatusDto = try self.getResponse(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/statuses",
            method: .POST,
            data: statusRequestDto,
            decodeTo: StatusDto.self
        )
        
        guard let statusId = createdStatusDto.id?.toId() else {
            throw SharedApplicationError.unwrap
        }
        
        return try await Status.query(on: self.db)
            .filter(\.$id == statusId)
            .first()!
    }
    
    func createStatuses(user: User, notePrefix: String, categoryId: String? = nil, amount: Int) async throws -> (statuses: [Status], attachments: [Attachment]) {
        var attachments: [Attachment] = []
        var statuses: [Status] = []

        for index in 1...amount {
            let attachment = try await self.createAttachment(user: user)
            attachments.append(attachment)
            
            let status = try await self.createStatus(user: user, note: "\(notePrefix) \(index)", attachmentIds: [attachment.stringId()!], categoryId: categoryId)
            statuses.append(status)
        }
        
        return (statuses, attachments)
    }
    
    func reblogStatus(user: User, status: Status) async throws -> Status {
        let reblogRequestDto = ReblogRequestDto(visibility: .public)
        
        let createdStatusDto = try self.getResponse(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/statuses/\(status.requireID())/reblog",
            method: .POST,
            data: reblogRequestDto,
            decodeTo: StatusDto.self
        )
        
        guard let statusId = createdStatusDto.id?.toId() else {
            throw SharedApplicationError.unwrap
        }
        
        return try await Status.query(on: self.db)
            .filter(\.$reblog.$id == statusId)
            .first()!
    }
    
    func replyStatus(user: User, comment: String, status: Status) async throws -> Status {
        return try await self.createStatus(user: user, note: comment, attachmentIds: [], replyToStatusId: status.stringId())
    }
    
    func favouriteStatus(user: User, status: Status) async throws {
        _ = try self.getResponse(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/statuses/\(status.requireID())/favourite",
            method: .POST,
            decodeTo: StatusDto.self
        )
    }
    
    func bookmarkStatus(user: User, status: Status) async throws {
        _ = try self.getResponse(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/statuses/\(status.requireID())/bookmark",
            method: .POST,
            decodeTo: StatusDto.self
        )
    }
    
    func clearFiles(attachments: [Attachment]) {
        for attachment in attachments {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
    }
}
