//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Entity used for sending paramteres to authorization page.
struct OAuthAuthorizePageDto {
    public let id: String
    public let csrfToken: String
    public let state: String
    public let scopes: [String]
    public let userName: String
    public let userFullName: String
    public let clientName: String
}

extension OAuthAuthorizePageDto: Content { }
