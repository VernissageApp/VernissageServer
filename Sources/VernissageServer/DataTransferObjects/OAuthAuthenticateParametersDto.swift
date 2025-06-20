//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Entity used form URL parameters for `/oauth/authorize` endpoint.
struct OAuthAuthenticateParametersDto {
    public let responseType: String
    public let clientId: String
    public let redirectUri: URI
    public let scope: String
    public let state: String?
    public let csrfToken: String?
    
    enum CodingKeys: String, CodingKey {
        case responseType = "response_type"
        case clientId = "client_id"
        case redirectUri = "redirect_uri"
        case scope
        case state
        case csrfToken = "csrf_token"
    }
}

extension OAuthAuthenticateParametersDto: Content { }
