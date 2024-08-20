//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public typealias ActorId = String
public typealias PrivateKeyPem = String
public typealias Path = String
public typealias UserAgent = String
public typealias Host = String
public typealias ObjectId = String

extension ActivityPub {
    public enum Users {
        case follow(ActorId, ActorId, PrivateKeyPem, Path, UserAgent, Host, Int64)
        case unfollow(ActorId, ActorId, PrivateKeyPem, Path, UserAgent, Host, Int64)
        case accept(ActorId, ActorId, PrivateKeyPem, Path, UserAgent, Host, Int64, ObjectId)
        case reject(ActorId, ActorId, PrivateKeyPem, Path, UserAgent, Host, Int64, ObjectId)
        case delete(ActorId, PrivateKeyPem, Path, UserAgent, Host)
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
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .unfollow(let sourceActorId, _, let privateKeyPem, let path, let userAgent, let host, _):
            return [:]
                .signature(actorId: sourceActorId,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .accept(_, let targetActorId, let privateKeyPem, let path, let userAgent, let host, _, _):
            return [:]
                .signature(actorId: targetActorId,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .reject(_, let targetActorId, let privateKeyPem, let path, let userAgent, let host, _, _):
            return [:]
                .signature(actorId: targetActorId,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .delete(let actorId, let privateKeyPem, let path, let userAgent, let host):
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
        case .follow(let sourceActorId, let targetActorId, _, _, _, _, let id):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys

            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .follow,
                            id: "\(sourceActorId)#follow/\(id)",
                            actor: .single(ActorDto(id: sourceActorId)),
                            to: nil,
                            object: .single(ObjectDto(id: targetActorId)),
                            summary: nil,
                            signature: nil,
                            published: nil)
            )
        case .unfollow(let sourceActorId, let targetActorId, _, _, _, _, let id):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys

            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .undo,
                            id: "\(sourceActorId)#follow/\(id)/undo",
                            actor: .single(ActorDto(id: sourceActorId)),
                            to: nil,
                            object: .single(ObjectDto(id: "\(sourceActorId)#follow/\(id)",
                                                          type: .follow,
                                                          object: FollowDto(actor: .single(ActorDto(id: sourceActorId)),
                                                                            object: .single(ObjectDto(id: targetActorId))))),
                            summary: nil,
                            signature: nil,
                            published: nil)
            )
        case .accept(let sourceActorId, let targetActorId, _, _, _, _, let id, let objectId):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .accept,
                            id: "\(targetActorId)#accept/follow/\(id)",
                            actor: .single(ActorDto(id: targetActorId)),
                            to: nil,
                            object: .single(ObjectDto(id: objectId,
                                                          type: .follow,
                                                          object: FollowDto(actor: .single(ActorDto(id: sourceActorId)),
                                                                            object: .single(ObjectDto(id: targetActorId))))),
                            summary: nil,
                            signature: nil,
                            published: nil)
            )
        case .reject(let sourceActorId, let targetActorId, _, _, _, _, let id, let objectId):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .reject,
                            id: "\(targetActorId)#reject/follow/\(id)",
                            actor: .single(ActorDto(id: targetActorId)),
                            to: nil,
                            object: .single(ObjectDto(id: objectId,
                                                          type: .follow,
                                                          object: FollowDto(actor: .single(ActorDto(id: sourceActorId)),
                                                                            object: .single(ObjectDto(id: targetActorId))))),
                            summary: nil,
                            signature: nil,
                            published: nil)
            )
        case .delete(let actorId, _, _, _, _):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .delete,
                            id: "\(actorId)#delete",
                            actor: .single(ActorDto(id: actorId)),
                            to: .multiple([
                                ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")
                            ]),
                            object: .single(ObjectDto(id: actorId)),
                            summary: nil,
                            signature: nil,
                            published: nil)
            )
        }
    }
}

