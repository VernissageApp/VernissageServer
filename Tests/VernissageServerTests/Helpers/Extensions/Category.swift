//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTVapor
import Fluent

extension App.Category {
    static func get(name: String) async throws -> App.Category? {
        return try await App.Category.query(on: SharedApplication.application().db)
            .filter(\.$name == name)
            .first()
    }
}
