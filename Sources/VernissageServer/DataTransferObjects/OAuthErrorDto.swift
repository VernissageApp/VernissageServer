//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// OAuth  error (RFC 6749).
///
/// If the request fails due to a missing, invalid, or mismatching
/// redirection URI, or if the client identifier is missing or invalid,
/// the authorization server SHOULD inform the resource owner of the
/// error and MUST NOT automatically redirect the user-agent to the
/// invalid redirection URI.
struct OAuthErrorDto {
    /// REQUIRED.  A single ASCII [USASCII] error code.
    var error: OAuthErrorCodeDto = .invalidRequest

    /// OPTIONAL.  Human-readable ASCII [USASCII] text providing
    /// additional information, used to assist the client developer in
    /// understanding the error that occurred.
    /// Values for the "error_description" parameter MUST NOT include
    /// characters outside the set %x20-21 / %x23-5B / %x5D-7E.
    var errorDescription: String?
        
    /// OPTIONAL.  A URI identifying a human-readable web page with
    /// information about the error, used to provide the client
    /// developer with additional information about the error.
    /// Values for the "error_uri" parameter MUST conform to the
    /// URI-reference syntax and thus MUST NOT include characters
    /// outside the set %x21 / %x23-5B / %x5D-7E.
    var errorUri: String?
    
    /// REQUIRED if a "state" parameter was present in the client
    /// authorization request.  The exact value received from the
    /// client.
    var state: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case errorUri = "error_uri"
        case state
    }
    
    init(_ errorDescription: String, error: OAuthErrorCodeDto = .invalidRequest, errorUri: String? = nil, state: String? = nil) {
        self.errorDescription = errorDescription
        self.error = error
        self.errorUri = errorUri
        self.state = state
    }
}

extension OAuthErrorDto: Content { }

extension OAuthErrorDto {
    func response(on request: Request) async throws -> Response {
        let response = try await self.encodeResponse(for: request)
        response.status = .badRequest

        return response
    }
}
