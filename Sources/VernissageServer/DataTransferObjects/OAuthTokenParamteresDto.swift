//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// The client makes a request to the token endpoint by sending the
/// following parameters using the "application/x-www-form-urlencoded"
/// format per Appendix B with a character encoding of UTF-8 in the HTTP
/// request entity-body.
struct OAuthTokenParamteresDto {
    /// Required. Value MUST be set to `authorization_code` or `refresh_token`.
    var grantType: String
    
    /// Required when `grantType` is set to `authorization_code`.  The authorization code received from the authorization server.
    var code: String?
    
    /// Required when `grantType` is set to `refresh_token`.  The refresh token issued to the client.
    var refreshToken: String?
                  
    /// Required when `grantType` is set to `authorization_code`.
    /// The value must be identical with value pass to `authenticate` endpoint.
    var redirectUri: String?
             
    /// Required when `grantType` is set to `authorization_code` or `client_credentials`.
    var clientId: String?

    /// Required when `grantType` is set to `client_credentials`.
    var clientSecret: String?
    
    /// Optional.  The scope of the access request as described by
    /// Section 3.3.  The requested scope MUST NOT include any scope
    /// not originally granted by the resource owner, and if omitted is
    /// treated as equal to the scope originally granted by the
    /// resource owner.
    var scope: String?

    enum CodingKeys: String, CodingKey {
        case code
        case grantType = "grant_type"
        case redirectUri = "redirect_uri"
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case refreshToken = "refresh_token"
        case scope
    }
}

extension OAuthTokenParamteresDto: Content { }
