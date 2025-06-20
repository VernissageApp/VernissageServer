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
    /// Single ASCII error code string.
    var error: RegisterOAuthClientErrorCodeDto
    
    /// Human-readable ASCII text description of the error used for debugging.
    var errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }

    init(_ errorDescription: String, error: RegisterOAuthClientErrorCodeDto = .invalidClientMetadata) {
        self.errorDescription = errorDescription
        self.error = error
    }
}

extension RegisterOAuthClientErrorDto: Content { }

extension RegisterOAuthClientErrorDto {
    func response(on request: Request) async throws -> Response {
        let response = try await self.encodeResponse(for: request)
        response.status = .badRequest

        return response
    }
}
