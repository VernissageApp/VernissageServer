//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

extension ActivityPub {
    public enum Notes {
        case get
        case create(NoteDto, ActorId, PrivateKeyPem, Path, UserAgent, Host)
        case announce(ObjectId, ActorId, Date, ActorId, ObjectId, PrivateKeyPem, Path, UserAgent, Host)
        case unannounce(ObjectId, ActorId, Date, ActorId, ObjectId, PrivateKeyPem, Path, UserAgent, Host)
        case delete(ActorId, ObjectId, PrivateKeyPem, Path, UserAgent, Host)
    }
}

extension ActivityPub.Notes: TargetType {
    public var method: Method {
        switch self {
        case .create, .announce, .delete:
            return .post
        default:
            return .get
        }
    }

    public var queryItems: [(String, String)]? {
        return nil
    }

    public var headers: [Header: String]? {
        switch self {
        case .create(_, let activityPubProfile, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: activityPubProfile,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path.lowercased(),
                           userAgent: userAgent,
                           host: host)
        case .announce(_, let activityPubProfile, _, _, _, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: activityPubProfile,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path.lowercased(),
                           userAgent: userAgent,
                           host: host)
        case .unannounce(_, let activityPubProfile, _, _, _, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: activityPubProfile,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path.lowercased(),
                           userAgent: userAgent,
                           host: host)
        case .delete(let actorId, _, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: actorId,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path.lowercased(),
                           userAgent: userAgent,
                           host: host)
        default:
            return [:]
                .contentTypeApplicationJson
                .acceptApplicationJson
        }
    }

    public var httpBody: Data? {
        switch self {
        case .create(let noteDto, let activityPubProfile, _, _, _, _):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .create,
                            id: "\(noteDto.id)/activity",
                            actor: .single(ActorDto(id: activityPubProfile)),
                            to: .single(ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")),
                            cc: .single(ActorDto(id: "\(activityPubProfile)/followers")),
                            object: .single(ObjectDto(id: noteDto.id, object: noteDto)),
                            summary: nil,
                            signature: nil,
                            published: noteDto.published))
        case .announce(let activityPubStatusId, let activityPubProfile, let published, let activityPubReblogProfile, let activityPubReblogStatusId, _, _, _, _):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .announce,
                            id: "\(activityPubStatusId)/activity",
                            actor: .single(ActorDto(id: activityPubProfile)),
                            to: .single(ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")),
                            cc: .multiple([
                                ActorDto(id: activityPubReblogProfile),
                                ActorDto(id: "\(activityPubProfile)/followers")
                            ]),
                            object: .single(ObjectDto(id: activityPubReblogStatusId)),
                            summary: nil,
                            signature: nil,
                            published: published.toISO8601String()))
        case .unannounce(let activityPubStatusId, let activityPubProfile, let published, let activityPubReblogProfile, let activityPubReblogStatusId, _, _, _, _):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .undo,
                            id: "\(activityPubStatusId)#announces/undo",
                            actor: .single(ActorDto(id: activityPubProfile)),
                            to: .single(ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")),
                            object: .single(ObjectDto(id: "\(activityPubStatusId)/activity",
                                                      type: .announce,
                                                      object: AnnouceDto(id: "\(activityPubStatusId)/activity",
                                                                         published: published.toISO8601String(),
                                                                         actor: .single(ActorDto(id: activityPubProfile)),
                                                                         to: .single(ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")),
                                                                         cc: .multiple([
                                                                            ActorDto(id: activityPubReblogProfile),
                                                                            ActorDto(id: "\(activityPubProfile)/followers")
                                                                         ]),
                                                                         object: .single(ObjectDto(id: activityPubReblogStatusId))))),
                            summary: nil,
                            signature: nil))
        case .delete(let actorId, let objectId, _, _, _, _):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .delete,
                            id: "\(objectId)#delete",
                            actor: .single(ActorDto(id: actorId)),
                            to: .multiple([
                                ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")
                            ]),
                            object: .single(ObjectDto(id: objectId, type: .note)),
                            summary: nil,
                            signature: nil,
                            published: nil)
            )
        default:
            return nil
        }
    }
}

