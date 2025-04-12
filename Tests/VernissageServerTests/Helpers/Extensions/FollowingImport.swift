//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func getFollowingImports(userId: Int64) async throws -> [FollowingImport] {
        return try await FollowingImport.query(on: self.db)
            .with(\.$followingImportItems)
            .filter(\.$user.$id == userId)
            .all()
    }
    
    func createFollwingImport(userId: Int64, accounts: [String]) async throws -> FollowingImport {
        let id = await ApplicationManager.shared.generateId()
        let followingImport = FollowingImport(id: id, userId: userId)
        
        _ = try await followingImport.save(on: self.db)

        for account in accounts {
            let newAccountId = await ApplicationManager.shared.generateId()
            let followingImportItem = FollowingImportItem(id: newAccountId, followingImportId: id, account: account, showBoosts: false, languages: "en_US")
            _ = try await followingImportItem.save(on: self.db)
        }
        
        return followingImport
    }
}
