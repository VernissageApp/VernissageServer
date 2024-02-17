//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct PublicSettingsDto {
    var webSentryDsn: String
    
    
    init(webSentryDsn: String) {
        self.webSentryDsn = webSentryDsn
    }
}

extension PublicSettingsDto: Content { }
