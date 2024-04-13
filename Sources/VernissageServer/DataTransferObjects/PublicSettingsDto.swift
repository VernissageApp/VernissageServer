//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct PublicSettingsDto {
    var webSentryDsn: String
    var maximumNumberOfInvitations: Int
    
    init(webSentryDsn: String, maximumNumberOfInvitations: Int) {
        self.webSentryDsn = webSentryDsn
        self.maximumNumberOfInvitations = maximumNumberOfInvitations
    }
}

extension PublicSettingsDto: Content { }
