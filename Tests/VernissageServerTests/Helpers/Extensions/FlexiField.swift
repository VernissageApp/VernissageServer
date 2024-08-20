//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension FlexiField {
    static func create(key: String,
                       value: String,
                       isVerified: Bool,
                       userId: Int64) async throws -> FlexiField {
        let flexiField = FlexiField(key: key, value: value, isVerified: isVerified, userId: userId)
        _ = try await flexiField.save(on: SharedApplication.application().db)
        return flexiField
    }
}
