//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

extension ActivityPub {
    public enum Notes {
        case get(ActorId, PrivateKeyPem, Path, UserAgent, Host)
        case create(NoteDto, ActorId, ActorId?, PrivateKeyPem, Path, UserAgent, Host)
        case announce(ObjectId, ActorId, Date, ActorId, ObjectId, PrivateKeyPem, Path, UserAgent, Host)
        case unannounce(ObjectId, ActorId, Date, ActorId, ObjectId, PrivateKeyPem, Path, UserAgent, Host)
        case like(ObjectId, ActorId, ObjectId, PrivateKeyPem, Path, UserAgent, Host)
        case unlike(ObjectId, ActorId, ObjectId, PrivateKeyPem, Path, UserAgent, Host)
        case delete(ActorId, ObjectId, PrivateKeyPem, Path, UserAgent, Host)
    }
}

extension ActivityPub.Notes: TargetType {
    public var method: Method {
        switch self {
        case .create, .announce, .delete, .like, .unlike:
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
        case .get(let activityPubProfile, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: activityPubProfile,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .create(_, let activityPubProfile, _, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: activityPubProfile,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .announce(_, let activityPubProfile, _, _, _, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: activityPubProfile,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .unannounce(_, let activityPubProfile, _, _, _, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: activityPubProfile,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .like(_, let actorId, _, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: actorId,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .unlike(_, let actorId, _, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: actorId,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        case .delete(let actorId, _, let privateKeyPem, let path, let userAgent, let host):
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
        case .get(_, _, _, _, _):
            return nil
        case .create(let noteDto, let activityPubProfile, let activityPubReplyProfile, _, _, _, _):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            let cc = self.createCc(activityPubProfile: activityPubProfile, activityPubReplyProfile: activityPubReplyProfile)
            let to = self.createTo(activityPubProfile: activityPubProfile, activityPubReplyProfile: activityPubReplyProfile)
            
            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .create,
                            id: "\(noteDto.id)/activity",
                            actor: .single(ActorDto(id: activityPubProfile)),
                            to: to,
                            cc: cc,
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
        case .like(let favouriteId, let actorId, let objectId, _, _, _, _):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .like,
                            id: "\(actorId)#likes/\(favouriteId)",
                            actor: .single(ActorDto(id: actorId)),
                            object: .single(ObjectDto(id: objectId)),
                            summary: nil,
                            signature: nil,
                            published: nil)
            )
        case .unlike(let favouriteId, let actorId, let objectId, _, _, _, _):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            return try? encoder.encode(
                ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                            type: .undo,
                            id: "\(actorId)#likes/\(favouriteId)/undo",
                            actor: .single(ActorDto(id: actorId)),
                            object: .single(ObjectDto(id: "\(actorId)#likes/\(favouriteId)",
                                                      type: .like,
                                                      object: LikeDto(id: "\(actorId)#likes/\(favouriteId)",
                                                                      actor: .single(ActorDto(id: actorId)),
                                                                      to: nil,
                                                                      cc: nil,
                                                                      object: .single(ObjectDto(id: objectId))))),
                            summary: nil,
                            signature: nil)
            )
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
        }
    }
        
    private func createCc(activityPubProfile: String, activityPubReplyProfile: String?) -> ComplexType<ActorDto> {
        if let activityPubReplyProfile {
            
            // For reply statuses we are always sending 'Unlisted'. For that kind #Public have to be specified in the cc field,
            // "followers" have to be send in the "to" field.
            return .multiple([
                    ActorDto(id: "https://www.w3.org/ns/activitystreams#Public"),
                    ActorDto(id: activityPubReplyProfile)])
        }
        
        // For regular statuses #Public have "to" be specified in to field.
        return .multiple([ActorDto(id: "\(activityPubProfile)/followers")])
    }
    
    private func createTo(activityPubProfile: String, activityPubReplyProfile: String?) -> ComplexType<ActorDto> {
        if activityPubReplyProfile != nil {
            
            // For reply statuses we are always sending 'Unlisted'. For that kind #Public have to be specified in the cc field,
            // "followers" have to be send in the "to" field.
            return ComplexType.multiple([ActorDto(id: "\(activityPubProfile)/followers")])
        }
        
        // For regular statuses #Public have to be specified in "to" field.
        return .multiple([ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")])
    }
}

