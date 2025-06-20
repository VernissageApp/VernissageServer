//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Register OAuth client error codes.
enum RegisterOAuthClientErrorCodeDto: String {
    /// The value of one or more redirection URIs is invalid.
    case invalidRedirectUri = "invalid_redirect_uri"
    
    /// The value of one of the client metadata fields is invalid and the
    /// server has rejected this request.  Note that an authorization
    /// server MAY choose to substitute a valid value for any requested
    /// parameter of a client's metadata.
    case invalidClientMetadata = "invalid_client_metadata"
    
    /// The software statement presented is not approved for use by this
    /// authorization server.
    case invalidSoftwareStatement = "invalid_software_statement"
}

extension RegisterOAuthClientErrorCodeDto: Content { }
