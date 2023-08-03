//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

public enum ActivityPubRequestPath {
    case sharedInbox
    case userInbox(String)
    case userOutbox(String)
    
    func path() -> String {
        switch self {
        case .sharedInbox: return "/shared/inbox"
        case .userInbox(let userName): return "/\(userName)/inbox"
        case .userOutbox(let userName): return "/\(userName)/outbox"
        }
    }
}

extension ActivityPubRequestPath: Content { }
