//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct SharedBusinessCardUpdateRequestDto {
    /// Third party name.
    var thirdPartyName: String?
    
    /// Third party email.
    var thirdPartyEmail: String?
    
    /// Base url to web application. It's used to send email with shared card url.
    var sharedCardUrl: String
}

extension SharedBusinessCardUpdateRequestDto: Content { }

extension SharedBusinessCardUpdateRequestDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("thirdPartyName", as: String?.self, is: .count(...100) || .nil, required: false)
        validations.add("thirdPartyEmail", as: String?.self, is: .email || .nil, required: false)
        validations.add("sharedCardUrl", as: String.self, is: .url)
    }
}
