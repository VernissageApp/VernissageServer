//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

extension ActivityPub {
    public enum Person {
        case search(ActorId, PrivateKeyPem, Path, UserAgent, Host)
    }
}

extension ActivityPub.Person: TargetType {
    public var method: Method {
        return .get
    }

    public var queryItems: [(String, String)]? {
        return nil
    }

    public var headers: [Header: String]? {
        switch self {
        case .search(let activityPubProfile, let privateKeyPem, let path, let userAgent, let host):
            return [:]
                .signature(actorId: activityPubProfile,
                           privateKeyPem: privateKeyPem,
                           body: self.httpBody,
                           httpMethod: self.method,
                           httpPath: path,
                           userAgent: userAgent,
                           host: host)
        }
    }

    public var httpBody: Data? {
        return nil
    }
}

