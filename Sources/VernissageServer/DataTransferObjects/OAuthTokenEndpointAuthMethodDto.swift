//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Requested authentication method for the
/// token endpoint.  Values defined by this specification are:
/// - "none": The client is a public client as defined in OAuth 2.0,
/// Section 2.1, and does not have a client secret.
/// - "client_secret_post": The client uses the HTTP POST parameters
/// as defined in OAuth 2.0, Section 2.3.1.
/// - "client_secret_basic": The client uses HTTP Basic as defined in
/// OAuth 2.0, Section 2.3.1.
enum OAuthTokenEndpointAuthMethodDto: String {
    case none
    case clientSecretPost = "client_secret_post"
    case clientSecretBasic = "client_secret_basic"
}

extension OAuthTokenEndpointAuthMethodDto: Content { }
