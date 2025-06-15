//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// OAuth dynamic client registration error (RFC 7591).
///
/// When an OAuth 2.0 error condition occurs, such as the client
/// presenting an invalid initial access token, the authorization server
/// returns an error response appropriate to the OAuth 2.0 token type.
///
/// When a registration error condition occurs, the authorization server
/// returns an HTTP 400 status code (unless otherwise specified) with
/// content type "application/json" consisting of a JSON object [RFC7159]
/// describing the error in the response body.
struct RegisterOAuthClientErrorDto {
    /// REQUIRED.  Single ASCII error code string.
    ///
    /// The specification defines the following error codes:
    ///
    /// - invalid_redirect_uri - The value of one or more redirection URIs is invalid.
    /// - invalid_client_metadata - The value of one of the client metadata fields is invalid and the
    /// server has rejected this request.  Note that an authorization
    /// server MAY choose to substitute a valid value for any requested
    /// parameter of a client's metadata.
    /// - invalid_software_statement - The software statement presented is invalid.
    /// unapproved_software_statement - The software statement presented is not approved for use by this
    /// authorization server.
    var error: String
    
    /// OPTIONAL.  Human-readable ASCII text description of the error used for debugging.
    var errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
