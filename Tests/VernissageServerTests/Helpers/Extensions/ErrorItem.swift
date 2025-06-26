//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createErrorItem(code: String? = nil, message: String) async throws -> ErrorItem {
        let id = await ApplicationManager.shared.generateId()

        let errorItem = ErrorItem(id: id,
                                  source: .server,
                                  code: code ?? String.createRandomString(length: 10),
                                  message: message,
                                  exception: "Exception \(message) \(String.createRandomString(length: 20))",
                                  userAgent: "Mozilla/5.0",
                                  clientVersion: "1.0.0-web",
                                  serverVersion: "1.0.0-api")

        _ = try await errorItem.save(on: self.db)
        return errorItem
    }

    func getErrorItem(code: String) async throws -> ErrorItem? {
        return try await ErrorItem.query(on: self.db)
            .filter(\.$code == code)
            .first()
    }
}
