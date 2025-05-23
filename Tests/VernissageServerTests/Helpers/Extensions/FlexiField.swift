//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func createFlexiField(key: String,
                value: String,
                isVerified: Bool,
                userId: Int64) async throws -> FlexiField {
        let id = await ApplicationManager.shared.generateId()
        let flexiField = FlexiField(id: id, key: key, value: value, isVerified: isVerified, userId: userId)
        _ = try await flexiField.save(on: self.db)
        return flexiField
    }
}
