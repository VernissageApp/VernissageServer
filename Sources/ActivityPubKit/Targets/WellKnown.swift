//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

extension ActivityPub {
    public enum WellKnown {
        case webfinger
        case nodeinfo
        case hostMeta
    }
}

extension ActivityPub.WellKnown: TargetType {
    public var method: Method {
        return .get
    }

    public var queryItems: [(String, String)]? {
        return nil
    }

    public var headers: [Header: String]? {
        switch self {
        case .webfinger:
            return [.accept: "application/jrd+json, application/json;q=0.9, application/xrd+xml;q=0.8"]
        case .nodeinfo:
            return [:]
                .contentTypeApplicationJson
                .acceptApplicationJson
        case .hostMeta:
            return [:]
                .contentTypeApplicationJson
                .acceptApplicationXml
        }
    }

    public var httpBody: Data? {
        return nil
    }
}

