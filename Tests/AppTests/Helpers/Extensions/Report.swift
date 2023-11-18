//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import Vapor
import Fluent

extension Report {
    static func get(userId: Int64) async throws -> Report? {
        return try await Report.query(on: SharedApplication.application().db)
            .filter(\.$user.$id == userId)
            .with(\.$user)
            .with(\.$reportedUser)
            .with(\.$status)
            .with(\.$considerationUser)
            .first()
    }
}
