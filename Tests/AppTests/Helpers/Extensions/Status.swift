//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import Vapor
import Fluent

extension Status {
    static func get(id: Int64) async throws -> Status? {
        return try await Status.query(on: SharedApplication.application().db).filter(\.$id == id).first()
    }
    
    static func get(reblogId: Int64) async throws -> Status? {
        return try await Status.query(on: SharedApplication.application().db).filter(\.$reblog.$id == reblogId).first()
    }

    static func create(user: User, note: String, attachmentIds: [String], visibility: StatusVisibilityDto = .public, replyToStatusId: String? = nil) async throws -> Status {
        let statusRequestDto = StatusRequestDto(note: note,
                                                visibility: visibility,
                                                sensitive: false,
                                                contentWarning: nil,
                                                commentsDisabled: false,
                                                replyToStatusId: replyToStatusId,
                                                attachmentIds: attachmentIds)

        let createdStatusDto = try SharedApplication.application().getResponse(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/statuses",
            method: .POST,
            data: statusRequestDto,
            decodeTo: StatusDto.self
        )
        
        guard let statusId = createdStatusDto.id?.toId() else {
            throw SharedApplicationError.unwrap
        }
        
        return try await Status.query(on: SharedApplication.application().db)
            .filter(\.$id == statusId)
            .first()!
    }
    
    static func createStatuses(user: User, notePrefix: String, amount: Int) async throws -> (statuses: [Status], attachments: [Attachment]) {        
        var attachments: [Attachment] = []
        var statuses: [Status] = []

        for index in 1...amount {
            let attachment = try await Attachment.create(user: user)
            attachments.append(attachment)
            
            let status = try await Status.create(user: user, note: "\(notePrefix) \(index)", attachmentIds: [attachment.stringId()!])
            statuses.append(status)
        }
        
        return (statuses, attachments)
    }
    
    static func reblog(user: User, status: Status) async throws -> Status {
        let reblogRequestDto = ReblogRequestDto(visibility: .public)
        
        let createdStatusDto = try SharedApplication.application().getResponse(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/statuses/\(status.requireID())/reblog",
            method: .POST,
            data: reblogRequestDto,
            decodeTo: StatusDto.self
        )
        
        guard let statusId = createdStatusDto.id?.toId() else {
            throw SharedApplicationError.unwrap
        }
        
        return try await Status.query(on: SharedApplication.application().db)
            .filter(\.$reblog.$id == statusId)
            .first()!
    }
    
    static func reply(user: User, comment: String, status: Status) async throws -> Status {
        return try await Status.create(user: user, note: comment, attachmentIds: [], replyToStatusId: status.stringId())
    }
    
    static func favourite(user: User, status: Status) async throws {
        _ = try SharedApplication.application().getResponse(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/statuses/\(status.requireID())/favourite",
            method: .POST,
            decodeTo: StatusDto.self
        )
    }
    
    static func bookmark(user: User, status: Status) async throws {
        _ = try SharedApplication.application().getResponse(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/statuses/\(status.requireID())/bookmark",
            method: .POST,
            decodeTo: StatusDto.self
        )
    }
    
    static func clearFiles(attachments: [Attachment]) {
        for attachment in attachments {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
    }
}



