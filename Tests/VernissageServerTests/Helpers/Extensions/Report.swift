//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createReport(
        userId: Int64,
        reportedUserId: Int64,
        statusId: Int64?,
        mainStatusId: Int64? = nil,
        comment: String?,
        forward: Bool = false,
        category: String? = nil,
        considerationDate: Date? = nil,
        considerationUserId: Int64? = nil
    ) async throws -> Report {
        let id = await ApplicationManager.shared.generateId()
        let report = Report(id: id,
                            userId: userId,
                            reportedUserId: reportedUserId,
                            statusId: statusId,
                            mainStatusId: mainStatusId,
                            comment: comment,
                            forward: forward,
                            category: category,
                            ruleIds: [1,2],
                            considerationDate: considerationDate,
                            considerationUserId: considerationUserId)
        _ = try await report.save(on: self.db)
        return report
    }
    
    func getReport(userId: Int64) async throws -> Report? {
        return try await Report.query(on: self.db)
            .filter(\.$user.$id == userId)
            .with(\.$user)
            .with(\.$reportedUser)
            .with(\.$status)
            .with(\.$considerationUser)
            .first()
    }
    
    func getReport(id: Int64) async throws -> Report? {
        return try await Report.query(on: self.db)
            .filter(\.$id == id)
            .with(\.$user)
            .with(\.$reportedUser)
            .with(\.$status)
            .with(\.$considerationUser)
            .first()
    }
}
