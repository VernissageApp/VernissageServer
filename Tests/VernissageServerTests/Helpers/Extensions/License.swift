//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func getLicense(code: String) async throws -> License? {
        return try await License.query(on: self.db).filter(\.$code == code).first()
    }
}
