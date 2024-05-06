//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension PushSubscription {
    static func create(userId: Int64, endpoint: String, userAgentPublicKey: String, auth: String) async throws -> PushSubscription {
        let pushSubscription = PushSubscription(userId: userId,
                                                endpoint: endpoint,
                                                userAgentPublicKey: userAgentPublicKey,
                                                auth: auth)

        _ = try await pushSubscription.save(on: SharedApplication.application().db)
        return pushSubscription
    }
    
    static func clear() async throws {
        let all = try await PushSubscription.query(on: SharedApplication.application().db).all()
        try await all.delete(on: SharedApplication.application().db)
    }
    
    static func get(id: Int64) async throws -> PushSubscription? {
        return try await PushSubscription.query(on: SharedApplication.application().db)
            .filter(\.$id == id)
            .first()
    }
    
    static func get(endpoint: String) async throws -> PushSubscription? {
        return try await PushSubscription.query(on: SharedApplication.application().db)
            .filter(\.$endpoint == endpoint)
            .first()
    }
}
