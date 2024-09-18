//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Application {
    func getDisposableEmail(domain: String) async throws -> VernissageServer.DisposableEmail? {
        return try await VernissageServer.DisposableEmail.query(on: self.db)
            .filter(\.$domainNormalized == domain.uppercased())
            .first()
    }
    
    func createDisposableEmail(domain: String) async throws -> VernissageServer.DisposableEmail {
        let disposableEmail = VernissageServer.DisposableEmail(domain: domain)
        _ = try await disposableEmail.save(on: self.db)
        return disposableEmail
    }
}
