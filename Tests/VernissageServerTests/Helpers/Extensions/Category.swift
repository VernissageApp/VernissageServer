//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension VernissageServer.Category {
    static func get(name: String) async throws -> VernissageServer.Category? {
        return try await VernissageServer.Category.query(on: SharedApplication.application().db)
            .filter(\.$name == name)
            .first()
    }
}
