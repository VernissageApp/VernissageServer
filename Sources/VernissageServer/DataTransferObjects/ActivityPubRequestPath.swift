//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

public enum ActivityPubRequestPath: Sendable {
    case sharedInbox
    case userInbox(String)
    case applicationUserInbox
    
    func path() -> String {
        switch self {
        case .sharedInbox: return "/shared/inbox"
        case .userInbox(let userName): return "/actors/\(userName)/inbox"
        case .applicationUserInbox: return "/actor/inbox"
        }
    }
}

extension ActivityPubRequestPath: Content { }
