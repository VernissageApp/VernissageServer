//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

extension ActivityPub {
    public enum Person {
        case search
    }
}

extension ActivityPub.Person: TargetType {
    public var path: String {
        return ""
    }

    public var method: Method {
        return .get
    }

    public var queryItems: [(String, String)]? {
        return nil
    }

    public var headers: [String: String]? {
        return [:]
            .contentTypeApplicationJson
            .acceptApplicationJson
    }

    public var httpBody: Data? {
        return nil
    }
}

