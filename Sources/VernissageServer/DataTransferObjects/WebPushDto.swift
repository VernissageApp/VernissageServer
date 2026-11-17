//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct WebPushDto {
    var vapidSubject: String
    var vapidPublicKey: String
    var vapidPrivateKey: String
    var endpoint: String
    var userAgentPublicKey: String
    var auth: String
    var title: String
    var body: String
    var icon: String
    var badgeCount: Int
    var conversationId: String? = nil
}

extension WebPushDto: Content { }
