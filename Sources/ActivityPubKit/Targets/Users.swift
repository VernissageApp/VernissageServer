//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public typealias ActorId = String
public typealias PrivateKeyPem = String
public typealias Path = String
public typealias UserAgent = String
public typealias Host = String

extension ActivityPub {
    public enum Users {
        case follow(ActorId, ActorId, PrivateKeyPem, Path, UserAgent, Host, Int64)
        case unfollow(ActorId, ActorId, PrivateKeyPem, Path, UserAgent, Host, Int64)
    }
}

extension ActivityPub.Users: TargetType {
    public var method: Method {
        return .post
    }

    public var queryItems: [(String, String)]? {
        return nil
    }

    public var headers: [Header: String]? {
        switch self {
        case .follow(let sourceActorId, _, let privateKeyPem, let path, let userAgent, let host, _):
            return [:]
                .signature(actorId: sourceActorId,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path.lowercased(),
                           userAgent: userAgent,
                           host: host)
        case .unfollow(let sourceActorId, _, let privateKeyPem, let path, let userAgent, let host, _):
            return [:]
                .signature(actorId: sourceActorId,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path.lowercased(),
                           userAgent: userAgent,
                           host: host)
        }
    }

    public var httpBody: Data? {
        switch self {
        case .follow(let sourceActorId, let targetActorId, _, _, _, _, let id):
            return try? JSONEncoder().encode(
                ActivityDto(context: .single("https://www.w3.org/ns/activitystreams"),
                            type: .follow,
                            id: "\(sourceActorId)#follow/\(id)",
                            actor: .single(.string(sourceActorId)),
                            to: nil,
                            object: .single(.string(targetActorId)),
                            summary: nil,
                            signature: nil)
            )
        case .unfollow(let sourceActorId, let targetActorId, _, _, _, _, let id):
            return try? JSONEncoder().encode(
                ActivityDto(context: .single("https://www.w3.org/ns/activitystreams"),
                            type: .undo,
                            id: "\(sourceActorId)#follow/\(id)/undo",
                            actor: .single(.string(sourceActorId)),
                            to: nil,
                            object: .single(.object(.init(id: "\(sourceActorId)#follow/\(id)",
                                                          type: .follow,
                                                          actor: .single(.string(sourceActorId)),
                                                          object: .single(.string(targetActorId))))),
                            summary: nil,
                            signature: nil)
            )
        }
    }
}
