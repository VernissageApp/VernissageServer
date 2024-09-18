//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createPushSubscription(userId: Int64, endpoint: String, userAgentPublicKey: String, auth: String) async throws -> PushSubscription {
        let pushSubscription = PushSubscription(userId: userId,
                                                endpoint: endpoint,
                                                userAgentPublicKey: userAgentPublicKey,
                                                auth: auth)

        _ = try await pushSubscription.save(on: self.db)
        return pushSubscription
    }
    
    func clearPushSubscriptions() async throws {
        let all = try await PushSubscription.query(on: self.db).all()
        try await all.delete(on: self.db)
    }
    
    func getPushSubscription(id: Int64) async throws -> PushSubscription? {
        return try await PushSubscription.query(on: self.db)
            .filter(\.$id == id)
            .first()
    }
    
    func getPushSubscription(endpoint: String) async throws -> PushSubscription? {
        return try await PushSubscription.query(on: self.db)
            .filter(\.$endpoint == endpoint)
            .first()
    }
}
