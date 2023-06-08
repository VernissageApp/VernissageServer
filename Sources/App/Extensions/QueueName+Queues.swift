//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues

extension QueueName {
    static let emails = QueueName(string: "emails")
    static let apUserInbox = QueueName(string: "apUserInbox")
    static let apUserOutbox = QueueName(string: "apUserOutbox")
    static let apSharedInbox = QueueName(string: "apSharedInbox")
}
