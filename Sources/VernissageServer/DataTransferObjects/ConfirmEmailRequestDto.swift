//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ConfirmEmailRequestDto {
    /// User id.
    var id: String
    
    /// UUID which will be used to confirm email.
    var confirmationGuid: String
}

extension ConfirmEmailRequestDto: Content { }
