//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

extension ActivityPub {
    public enum WellKnown {
        case webfinger(String)
        case nodeinfo
        case hostMeta
    }
}

extension ActivityPub.WellKnown: TargetType {
    public var method: Method {
        return .get
    }

    public var queryItems: [(String, String)]? {
        switch self {
        case .webfinger(let resource):
            return [
                ("resource", "acct:\(resource)")
            ]
        default:
            return nil
        }
    }

    public var headers: [Header: String]? {
        return [:]
            .contentTypeApplicationJson
            .acceptApplicationJson
    }

    public var httpBody: Data? {
        return nil
    }
}

