//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Timeline kind exposed by the API.
enum TimelineKindDto: String {
    case `private`
    case local
    case federated
    case featured
}

extension TimelineKindDto {
    func translate() -> TimelineKind {
        switch self {
        case .private:
            return .private
        case .local:
            return .local
        case .federated:
            return .federated
        case .featured:
            return .featured
        }
    }
}

extension TimelineKindDto: Content { }
