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
    private var apiPath: String { return "/.well-known" }

    public var path: String {
        switch self {
        case .webfinger(_):
            return "\(apiPath)/webfinger"
        case .nodeinfo:
            return "\(apiPath)/nodeinfo"
        case .hostMeta:
            return "\(apiPath)/host-meta"
        }
    }

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

    public var headers: [String: String]? {
        return [:].contentTypeApplicationJson
    }

    public var httpBody: Data? {
        return nil
    }
}

