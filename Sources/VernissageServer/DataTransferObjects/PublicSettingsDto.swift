//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct PublicSettingsDto {
    var webSentryDsn: String
    var maximumNumberOfInvitations: Int
    var isOpenAIEnabled: Bool
    var webPushVapidPublicKey: String?
    var patreonUrl: String?
    
    init(webSentryDsn: String, maximumNumberOfInvitations: Int, isOpenAIEnabled: Bool, webPushVapidPublicKey: String?, patreonUrl: String?) {
        self.webSentryDsn = webSentryDsn
        self.maximumNumberOfInvitations = maximumNumberOfInvitations
        self.isOpenAIEnabled = isOpenAIEnabled
        self.webPushVapidPublicKey = webPushVapidPublicKey
        self.patreonUrl = patreonUrl
    }
}

extension PublicSettingsDto: Content { }
