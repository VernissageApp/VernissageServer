//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension VernissageServer.DisposableEmail {
    static func get(domain: String) async throws -> VernissageServer.DisposableEmail? {
        return try await VernissageServer.DisposableEmail.query(on: SharedApplication.application().db)
            .filter(\.$domainNormalized == domain.uppercased())
            .first()
    }
    
    static func create(domain: String) async throws -> DisposableEmail {
        let disposableEmail = DisposableEmail(domain: domain)
        _ = try await disposableEmail.save(on: SharedApplication.application().db)
        return disposableEmail
    }
}
