//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Array of OAuth 2.0 grant type strings that the client can use at
/// the token endpoint.  These grant types are defined as follows:
/// - `authorization_code`: The authorization code grant type defined
/// in OAuth 2.0, Section 4.1.
/// - `mplicit`: The implicit grant type defined in OAuth 2.0,
/// Section 4.2.
/// - `password`: The resource owner password credentials grant type
/// defined in OAuth 2.0, Section 4.3.
/// - `client_credentials`: The client credentials grant type defined
/// in OAuth 2.0, Section 4.4.
/// - `refresh_token`: The refresh token grant type defined in OAuth
/// 2.0, Section 6.
/// - `urn:ietf:params:oauth:grant-type:jwt-bearer`: The JWT Bearer
/// Token Grant Type defined in OAuth JWT Bearer Token Profiles
/// [RFC7523].
/// - `urn:ietf:params:oauth:grant-type:saml2-bearer`: The SAML 2.0
/// Bearer Assertion Grant defined in OAuth SAML 2 Bearer Token
/// Profiles [RFC7522].
enum OAuthGrantTypeDto: String {
    case authorizationCode = "authorization_code"
    case implicit
    case password
    case clientCredentials = "client_credentials"
    case refreshToken = "refresh_token"
    case jwtBearer = "urn:ietf:params:oauth:grant-type:jwt-bearer"
    case saml2Bearer = "urn:ietf:params:oauth:grant-type:saml2-bearer"
}

extension OAuthGrantTypeDto: Content { }
