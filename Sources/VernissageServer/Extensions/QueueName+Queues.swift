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
    static let urlValidator = QueueName(string: "urlValidator")
    static let userDeleter = QueueName(string: "userDeleter")
    
    static let statusSender = QueueName(string: "statusSender")
    static let statusDeleter = QueueName(string: "statusDeleter")
    static let statusReblogger = QueueName(string: "statusReblogger")
    static let statusUnreblogger = QueueName(string: "statusUnreblogger")

    static let apUserInbox = QueueName(string: "apUserInbox")
    static let apUserOutbox = QueueName(string: "apUserOutbox")
    static let apSharedInbox = QueueName(string: "apSharedInbox")
    static let apFollowRequester = QueueName(string: "apFollowRequester")
    static let apFollowResponder = QueueName(string: "apFollowResponder")
}