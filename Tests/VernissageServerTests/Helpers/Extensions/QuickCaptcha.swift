//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createQuickCaptcha(key: String, text: String) async throws -> QuickCaptcha {
        let id = await ApplicationManager.shared.generateId()
        let quickCaptcha = QuickCaptcha(id: id, key: key, text: text)
        _ = try await quickCaptcha.save(on: self.db)
        return quickCaptcha
    }
        
    func getQuickCaptcha(id: Int64) async throws -> QuickCaptcha? {
        return try await QuickCaptcha.query(on: self.db)
            .filter(\.$id == id)
            .first()
    }
    
    func getQuickCaptcha(key: String) async throws -> QuickCaptcha? {
        return try await QuickCaptcha.query(on: self.db)
            .filter(\.$key == key)
            .first()
    }
}
