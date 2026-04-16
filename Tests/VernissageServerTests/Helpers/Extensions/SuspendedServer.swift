//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func clearSuspendedServers() async throws {
        let all = try await SuspendedServer.query(on: self.db).all()
        try await all.delete(on: self.db)
    }

    func getSuspendedServer(hostNormalized: String) async throws -> SuspendedServer? {
        return try await SuspendedServer.query(on: self.db)
            .filter(\.$hostNormalized == hostNormalized)
            .first()
    }
}
