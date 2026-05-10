//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

extension ActivityPub {
    public enum Collections {
        case get(ActorId, PrivateKeyPem, Path, UserAgent, Host)
        case add(ObjectId, ActorId, ObjectId, PrivateKeyPem, Path, UserAgent, Host, Int64)
        case remove(ObjectId, ActorId, ObjectId, PrivateKeyPem, Path, UserAgent, Host, Int64)
    }
}

extension ActivityPub.Collections: TargetType {
    public var method: Method {
        switch self {
        case .get:
            return .get
        case .add, .remove:
            return .post
        }
    }

    public var queryItems: [(String, String)]? {
        return nil
    }

    public var headers: [Header: String]? {
        switch self {
        case .get(let actorId, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: actorId,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .add(_, let actorId, _, let privateKeyPem, let path, let userAgent, let host, _):
            return [:]
                .signature(actorId: actorId,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .remove(_, let actorId, _, let privateKeyPem, let path, let userAgent, let host, _):
            return [:]
                .signature(actorId: actorId,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        }
    }

    public var httpBody: Data? {
        switch self {
        case .get:
            return nil
        case .add(let objectId, let actorId, let targetId, _, _, _, _, let id):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys

            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .add,
                            id: "\(actorId)#featured/\(id)/add",
                            actor: .single(ActorDto(id: actorId)),
                            object: .single(ObjectDto(id: objectId)),
                            target: .single(ActorDto(id: targetId)),
                            summary: nil,
                            signature: nil,
                            published: nil)
            )
        case .remove(let objectId, let actorId, let targetId, _, _, _, _, let id):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys

            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .remove,
                            id: "\(actorId)#featured/\(id)/remove",
                            actor: .single(ActorDto(id: actorId)),
                            object: .single(ObjectDto(id: objectId)),
                            target: .single(ActorDto(id: targetId)),
                            summary: nil,
                            signature: nil,
                            published: nil)
            )
        }
    }
}
