//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

extension ActivityPub {
    public enum Flag {
        case create(ObjectId, ActorId, ActorId, [ObjectId], String?, PrivateKeyPem, Path, UserAgent, Host)
    }
}

extension ActivityPub.Flag: TargetType {
    public var method: Method {
        return .post
    }

    public var queryItems: [(String, String)]? {
        return nil
    }

    public var headers: [Header: String]? {
        switch self {
        case .create(_, let actorId, _, _, _, let privateKeyPem, let path, let userAgent, let host):
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
        case .create(let id, let actorId, let reportedActorId, let reportedObjectIds, let content, _, _, _, _):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            return try? encoder.encode(
                ActivityDto(
                    context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                    type: .flag,
                    id: "\(actorId)#flags/\(id)",
                    actor: .single(ActorDto(id: actorId)),
                    to: .single(ActorDto(id: reportedActorId)),
                    object: self.createObject(reportedActorId: reportedActorId, reportedObjectIds: reportedObjectIds),
                    summary: nil,
                    signature: nil,
                    content: content
                )
            )
        }
    }
    
    private func createObject(reportedActorId: String, reportedObjectIds: [String]) -> ComplexType<ObjectDto> {
        if reportedObjectIds.isEmpty {
            return .single(ObjectDto(id: reportedActorId))
        }
        
        let objects = [reportedActorId] + reportedObjectIds
        return .multiple(objects.map { ObjectDto(id: $0) })
    }
}
