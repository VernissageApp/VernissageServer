//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Application {
    func getCategory(name: String) async throws -> VernissageServer.Category? {
        return try await VernissageServer.Category.query(on: self.db)
            .filter(\.$name == name)
            .first()
    }
}
