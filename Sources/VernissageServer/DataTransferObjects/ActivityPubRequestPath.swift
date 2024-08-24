//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

public enum ActivityPubRequestPath {
    case sharedInbox
    case userInbox(String)
    case userOutbox(String)
    case applicationUserInbox
    case applicationUserOutbox
    
    func path() -> String {
        switch self {
        case .sharedInbox: return "/shared/inbox"
        case .userInbox(let userName): return "/actors/\(userName)/inbox"
        case .userOutbox(let userName): return "/actors/\(userName)/outbox"
        case .applicationUserInbox: return "/actor/inbox"
        case .applicationUserOutbox: return "/actor/outbox"
        }
    }
}

extension ActivityPubRequestPath: Content { }
