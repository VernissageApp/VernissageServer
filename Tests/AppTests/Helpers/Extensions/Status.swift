//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import Vapor
import Fluent

extension Status {
    static func get(id: Int64) async throws -> Status {
        guard let status = try await Status.query(on: SharedApplication.application().db).filter(\.$id == id).first() else {
            throw SharedApplicationError.unwrap
        }

        return status
    }

    static func create(user: User, note: String, attachmentIds: [String], visibility: StatusVisibilityDto = .public) async throws -> Status {
        let statusRequestDto = StatusRequestDto(note: note,
                                                visibility: visibility,
                                                sensitive: false,
                                                contentWarning: nil,
                                                commentsDisabled: false,
                                                replyToStatusId: nil,
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
}



