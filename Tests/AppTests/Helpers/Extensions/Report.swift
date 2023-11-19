//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import Vapor
import Fluent

extension Report {
    static func create(
        userId: Int64,
        reportedUserId: Int64,
        statusId: Int64?,
        comment: String?,
        forward: Bool = false,
        category: String? = nil,
        considerationDate: Date? = nil,
        considerationUserId: Int64? = nil
    ) async throws -> Report {
        let report = Report(userId: userId,
                            reportedUserId: reportedUserId,
                            statusId: statusId,
                            comment: comment,
                            forward: forward,
                            category: category,
                            ruleIds: [1,2],
                            considerationDate: considerationDate,
                            considerationUserId: considerationUserId)
        _ = try await report.save(on: SharedApplication.application().db)
        return report
    }
    
    static func get(userId: Int64) async throws -> Report? {
        return try await Report.query(on: SharedApplication.application().db)
            .filter(\.$user.$id == userId)
            .with(\.$user)
            .with(\.$reportedUser)
            .with(\.$status)
            .with(\.$considerationUser)
            .first()
    }
    
    static func get(id: Int64) async throws -> Report? {
        return try await Report.query(on: SharedApplication.application().db)
            .filter(\.$id == id)
            .with(\.$user)
            .with(\.$reportedUser)
            .with(\.$status)
            .with(\.$considerationUser)
            .first()
    }
}
