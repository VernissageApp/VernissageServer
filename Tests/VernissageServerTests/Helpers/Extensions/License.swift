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
    
    func createLicense(name: String, code: String, description: String, url: String?) async throws -> License {
        let id = await ApplicationManager.shared.generateId()
        let license = License(id: id,
                              name: name,
                              code: code,
                              description: description,
                              url: url)
        _ = try await license.save(on: self.db)
        return license
    }
}
