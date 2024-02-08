//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ResendEmailConfirmationDto {
    /// Base url to web application. It's used to redirect from email about email confirmation to correct web application page.  
    var redirectBaseUrl: String
}

extension ResendEmailConfirmationDto: Content { }
