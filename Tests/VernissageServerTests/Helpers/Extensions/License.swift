//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import Vapor
import Fluent

extension License {
    static func get(code: String) async throws -> License? {
        return try await License.query(on: SharedApplication.application().db).filter(\.$code == code).first()
    }
}
